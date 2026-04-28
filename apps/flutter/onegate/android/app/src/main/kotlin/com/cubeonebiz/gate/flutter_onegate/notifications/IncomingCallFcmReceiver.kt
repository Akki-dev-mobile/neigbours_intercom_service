package com.cubeonebiz.gate.flutter_onegate.notifications

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import com.hiennv.flutter_callkit_incoming.CallkitConstants
import com.hiennv.flutter_callkit_incoming.CallkitIncomingActivity
import com.hiennv.flutter_callkit_incoming.Data
import org.json.JSONObject

class IncomingCallFcmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "IncomingCallFcmReceiver"
        private const val CHANNEL_ID = "onegate_incoming_calls"
        private const val MISSED_CHANNEL_ID = "onegate_missed_calls"
        private const val GUARD_PREFS = "incoming_call_guard_native"
        private const val GUARD_CALL_ID_KEY = "call_id"
        private const val GUARD_TS_KEY = "ts_ms"
        private const val GUARD_TTL_MS = 45_000L
        private const val PENDING_TERMINAL_KEY = "pending_call_terminal_event_v1"
        private const val PENDING_TERMINAL_PER_CALL_PREFIX = "pending_call_terminal_event_"
        private const val PENDING_TERMINAL_TTL_MS = 180_000L
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.google.android.c2dm.intent.RECEIVE") return

        val extras = intent.extras ?: Bundle()
        val payload = extrasToMap(extras)
        if (payload.isEmpty()) return

        val action = normalizeAction(payload)
        val callId = (
            payload["call_id"]
                ?: payload["callId"]
                ?: payload["id"]
                ?: payload["uuid"]
            )?.trim().orEmpty()
        val meetingId = (payload["meeting_id"] ?: payload["meetingId"])?.trim().orEmpty()
        val jitsiUrl = (payload["jitsi_url"] ?: payload["jitsi_meeting_url"])?.trim().orEmpty()
        val terminalLike = setOf(
            "call_ended",
            "ended",
            "call_terminated",
            "terminated",
            "remote_ended",
            "ended_by_caller",
            "ended_by_receiver",
            "declined",
            "call_declined",
            "rejected",
            "call_rejected",
            "missed",
            "timeout",
            "caller_cancel",
            "call_cancelled",
            "call_canceled",
            "cancelled",
            "canceled",
        )
        if (callId.isNotEmpty() && action != null && terminalLike.contains(action)) {
            Log.i(
                TAG,
                "Terminal payload in receiver callId=$callId " +
                    "rawAction=${payload["action"] ?: payload["event"] ?: payload["type"] ?: payload["status"] ?: payload["reason"]} " +
                    "normalizedAction=$action status=${payload["status"]} reason=${payload["reason"]} " +
                    "ended_by=${payload["ended_by"] ?: payload["endedBy"]}",
            )
            handleTerminalEvent(context, payload, callId, action)
            return
        }

        val incomingLike = setOf(
            "incoming_call",
            "call_ringing",
            "ringing",
            "incoming",
            "call_initiated",
            "call_created",
            "call_ring",
        )
        val isIncomingByAction = action != null && incomingLike.contains(action)
        val isIncomingByShape =
            (action == null || action.isEmpty()) && callId.isNotEmpty() &&
                (meetingId.isNotEmpty() || jitsiUrl.isNotEmpty())

        if (isAppInForeground(context)) {
            // Foreground incoming path is handled by Flutter FirebaseMessaging.onMessage.
            // Some OEM/FCM combinations still flash a system heads-up for notification+data
            // payloads; clear that transient tray notification in foreground only.
            if (isIncomingByAction || isIncomingByShape) {
                try {
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(callId.hashCode())
                    nm.cancelAll()
                    Log.i(TAG, "Cleared transient foreground incoming notification callId=$callId")
                } catch (t: Throwable) {
                    Log.w(TAG, "Failed clearing foreground incoming notification callId=$callId", t)
                }
            }
            // Keep terminal handling above this return so we still close stale incoming UI
            // if Flutter misses a foreground terminal payload.
            return
        }

        if (!isIncomingByAction && !isIncomingByShape) return

        // Validate before guard start to avoid lock leaks.
        if (callId.isEmpty() || (meetingId.isEmpty() && jitsiUrl.isEmpty())) {
            Log.w(TAG, "Ignoring malformed incoming payload callId=$callId action=$action")
            return
        }
        if (!tryStartGuard(context, callId)) return

        try {
            showImmediateIncomingUi(context, payload, callId)
            Log.i(TAG, "Displayed incoming call UI callId=$callId")
        } catch (t: Throwable) {
            clearGuard(context, callId)
            Log.e(TAG, "Failed to display incoming call UI callId=$callId", t)
        }
    }

    private fun normalizeAction(payload: Map<String, String>): String? {
        val raw = (
            payload["action"]
                ?: payload["event"]
                ?: payload["type"]
                ?: payload["status"]
                ?: payload["reason"]
            )?.trim()
        if (raw.isNullOrEmpty()) return null
        val snake = raw
            .replace(Regex("([a-z0-9])([A-Z])"), "$1_$2")
            .replace("-", "_")
            .lowercase()
        val normalized = when (snake) {
            "callended", "call_end", "hangup",
            "ended_by_caller", "ended_by_receiver", "remote_ended",
            "terminated", "call_terminated" -> "call_ended"
            "declined", "call_declined" -> "call_declined"
            "rejected", "call_rejected" -> "call_rejected"
            "receiver_declined" -> "call_declined"
            "caller_cancel", "call_cancelled", "call_canceled", "cancelled", "canceled" -> "call_ended"
            "missed" -> "missed"
            "timeout" -> "timeout"
            else -> snake
        }
        Log.i(TAG, "normalizeAction raw=$raw snake=$snake normalized=$normalized")
        return normalized
    }

    private fun handleTerminalEvent(
        context: Context,
        payload: Map<String, String>,
        callId: String,
        action: String,
    ) {
        val hadActiveGuard = isGuardActive(context, callId)
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // Close any ongoing full-screen incoming call notification immediately.
            nm.cancel(callId.hashCode())
            sendCallkitEndedBroadcast(context, payload, callId)
            if (hadActiveGuard) {
                clearGuard(context, callId)
            }
            persistPendingTerminalEvent(context, payload, callId)
            val isDeclinedByUser = isDeclinedByUser(payload, action)
            if (!isDeclinedByUser) {
                showMissedCallbackNotification(context, payload, callId)
            }
            Log.i(
                TAG,
                "Processed terminal event action=$action callId=$callId hadActiveGuard=$hadActiveGuard",
            )
        } catch (t: Throwable) {
            Log.e(TAG, "Failed processing terminal event action=$action callId=$callId", t)
        }
    }

    private fun sendCallkitEndedBroadcast(
        context: Context,
        payload: Map<String, String>,
        callId: String,
    ) {
        try {
            val data = Bundle().apply {
                putString(CallkitConstants.EXTRA_CALLKIT_ID, callId)
                putString(
                    CallkitConstants.EXTRA_CALLKIT_NAME_CALLER,
                    payload["caller_name"]?.takeIf { it.isNotBlank() } ?: "Incoming Call",
                )
                putString(
                    CallkitConstants.EXTRA_CALLKIT_HANDLE,
                    payload["caller_phone"]?.takeIf { it.isNotBlank() } ?: "OneGate",
                )
                putInt(
                    CallkitConstants.EXTRA_CALLKIT_TYPE,
                    if ((payload["call_type"] ?: "").lowercase() == "audio") 0 else 1,
                )
                putSerializable(CallkitConstants.EXTRA_CALLKIT_EXTRA, HashMap(payload))
            }

            val intent = Intent().apply {
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_ENDED}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                // Match explicit receiver class used by plugin.
                component = ComponentName(
                    context.packageName,
                    "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver",
                )
            }
            context.sendBroadcast(intent)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to send CallKit ended broadcast callId=$callId", t)
        }
    }

    private fun persistPendingTerminalEvent(
        context: Context,
        payload: Map<String, String>,
        callId: String,
    ) {
        try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
            val nowMs = System.currentTimeMillis()
            val dataJson = JSONObject()
            payload.forEach { (key, value) ->
                dataJson.put(key, value)
            }
            dataJson.put("call_id", callId)

            val envelope = JSONObject()
            envelope.put("ts_ms", nowMs)
            envelope.put("data", dataJson)

            // Mirror Dart PendingCallTerminalEventStore format so Flutter uses the
            // same terminal handler path on next replay.
            prefs.edit()
                .putString(PENDING_TERMINAL_KEY, envelope.toString())
                .putString("$PENDING_TERMINAL_PER_CALL_PREFIX$callId", envelope.toString())
                .apply()

            // Prune stale per-call keys opportunistically.
            val all = prefs.all
            val editor = prefs.edit()
            all.forEach { (key, value) ->
                if (!key.startsWith(PENDING_TERMINAL_PER_CALL_PREFIX)) return@forEach
                val raw = value as? String ?: return@forEach
                try {
                    val parsed = JSONObject(raw)
                    val ts = parsed.optLong("ts_ms", 0L)
                    val age = nowMs - ts
                    if (ts <= 0L || age < 0L || age > PENDING_TERMINAL_TTL_MS) {
                        editor.remove(key)
                    }
                } catch (_: Throwable) {
                    editor.remove(key)
                }
            }
            editor.apply()
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to persist pending terminal event callId=$callId", t)
        }
    }

    private fun showMissedCallbackNotification(
        context: Context,
        payload: Map<String, String>,
        callId: String,
    ) {
        ensureMissedChannel(context)
        val callerName = payload["caller_name"]?.takeIf { it.isNotBlank() } ?: "Missed call"
        val callerPhone = payload["caller_phone"]?.takeIf { it.isNotBlank() } ?: "OneGate"
        val action = (payload["action"] ?: payload["status"])?.trim()?.lowercase()
        val subtitle = when (action) {
            "call_declined", "declined", "call_rejected", "rejected", "ended_by_receiver" -> "Declined by user"
            else -> "Missed call"
        }
        val intent = Intent(context, MissedCallCallbackActionReceiver::class.java).apply {
            putExtra("call_id", callId)
            putExtra("caller_name", callerName)
            putExtra("caller_phone", callerPhone)
            putExtra("caller_user_id", payload["caller_user_id"] ?: payload["from_user_id"] ?: "")
            putExtra("from_user_id", payload["from_user_id"] ?: payload["caller_user_id"] ?: "")
            putExtra("image", payload["image"] ?: payload["image_avatar_url"] ?: "")
            putExtra("meeting_id", payload["meeting_id"] ?: payload["meetingId"] ?: "")
            putExtra("meetingId", payload["meetingId"] ?: payload["meeting_id"] ?: "")
            putExtra("jitsi_url", payload["jitsi_url"] ?: payload["jitsi_meeting_url"] ?: "")
            putExtra("jitsi_meeting_url", payload["jitsi_meeting_url"] ?: payload["jitsi_url"] ?: "")
            putExtra("callback_action", "notification_tap")
            putExtra("notification_id", callId.hashCode() xor 73_331)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            (callId.hashCode() xor 73_331),
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            },
        )
        val notification = NotificationCompat.Builder(context, MISSED_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_missed)
            .setContentTitle(callerName)
            .setContentText(callerPhone)
            .setSubText(subtitle)
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.sym_action_call,
                "Call back",
                pendingIntent,
            )
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify((callId.hashCode() xor 73_331), notification)
    }

    private fun showImmediateIncomingUi(
        context: Context,
        payload: Map<String, String>,
        callId: String,
    ) {
        val callerName = payload["caller_name"]?.takeIf { it.isNotBlank() } ?: "Incoming Call"
        val callerPhone = payload["caller_phone"]?.takeIf { it.isNotBlank() } ?: "OneGate"
        val image = payload["image"] ?: payload["image_avatar_url"] ?: ""
        val callType = if ((payload["call_type"] ?: "").lowercase() == "audio") 0 else 1

        val extra = hashMapOf<String, Any?>(
            "action" to (payload["action"] ?: "incoming_call"),
            "call_id" to callId,
            "call_type" to (payload["call_type"] ?: "video"),
            "caller_name" to callerName,
            "caller_phone" to callerPhone,
            "meeting_id" to (payload["meeting_id"] ?: payload["meetingId"] ?: ""),
            "meetingId" to (payload["meetingId"] ?: payload["meeting_id"] ?: ""),
            "jitsi_url" to (payload["jitsi_url"] ?: payload["jitsi_meeting_url"] ?: ""),
            "jitsi_meeting_url" to (payload["jitsi_meeting_url"] ?: payload["jitsi_url"] ?: ""),
            "image" to image,
        )

        val data = Data(
            mapOf(
                "id" to callId,
                "nameCaller" to callerName,
                "appName" to "OneGate",
                "handle" to callerPhone,
                "avatar" to image,
                "type" to callType,
                "duration" to 60_000L,
                "textAccept" to "Accept",
                "textDecline" to "Decline",
                "extra" to extra,
                "android" to mapOf(
                    "isShowFullLockedScreen" to true,
                    "isImportant" to true,
                    "incomingCallNotificationChannelName" to "Incoming Calls",
                    "missedCallNotificationChannelName" to "Missed Calls",
                    "ringtonePath" to "incoming_call",
                    "isCustomNotification" to true,
                    "isShowLogo" to true,
                    "logoUrl" to "assets/media/images/oneapptm.png",
                    "backgroundColor" to "#FDE7E7",
                    "actionColor" to "#4CAF50",
                    "textColor" to "#7A1E1E",
                ),
            ),
        )
        val bundle = data.toBundle()

        val fullScreenIntent = CallkitIncomingActivity.getIntent(context, bundle)
        fullScreenIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
        )

        // Prefer launching the call UI activity directly.
        // This avoids showing an intermediate heads-up banner on some OEM builds.
        try {
            context.startActivity(fullScreenIntent)
            Log.i(TAG, "Launched incoming call activity directly callId=$callId")
            return
        } catch (t: Throwable) {
            Log.w(
                TAG,
                "Direct activity launch failed; falling back to full-screen notification callId=$callId",
                t,
            )
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            callId.hashCode(),
            fullScreenIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            },
        )

        ensureIncomingChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(callerName)
            .setContentText(callerPhone)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setTimeoutAfter(60_000L)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(callId.hashCode(), notification)
    }

    private fun ensureIncomingChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = nm.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming Calls",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        channel.description = "Incoming call alerts shown as full-screen notifications."
        channel.enableVibration(true)
        nm.createNotificationChannel(channel)
    }

    private fun ensureMissedChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = nm.getNotificationChannel(MISSED_CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            MISSED_CHANNEL_ID,
            "Missed Calls",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        channel.description = "Missed call alerts and callback actions."
        channel.enableVibration(true)
        nm.createNotificationChannel(channel)
    }

    private fun isAppInForeground(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        @Suppress("DEPRECATION")
        val running = am.runningAppProcesses ?: return false
        return running.any {
            it.processName == context.packageName &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }

    private fun extrasToMap(extras: Bundle): Map<String, String> {
        val out = mutableMapOf<String, String>()
        for (key in extras.keySet()) {
            val value = extras.get(key) ?: continue
            out[key] = value.toString()
        }
        return out
    }

    private fun isDeclinedByUser(payload: Map<String, String>, normalizedAction: String): Boolean {
        val declinedLike = setOf(
            "call_declined",
            "declined",
            "call_rejected",
            "rejected",
            "ended_by_receiver",
            "receiver_declined",
        )
        if (declinedLike.contains(normalizedAction.trim().lowercase())) return true

        val rawKeys = listOf("action", "event", "type", "status", "reason")
        for (key in rawKeys) {
            val raw = payload[key]?.trim()?.lowercase() ?: continue
            val snake = raw
                .replace(Regex("([a-z0-9])([A-Z])"), "$1_$2")
                .replace("-", "_")
                .lowercase()
            if (declinedLike.contains(snake)) return true
        }
        return false
    }

    private fun tryStartGuard(context: Context, callId: String): Boolean {
        val prefs = context.getSharedPreferences(GUARD_PREFS, Context.MODE_PRIVATE)
        val existingCallId = prefs.getString(GUARD_CALL_ID_KEY, null)
        val existingTs = prefs.getLong(GUARD_TS_KEY, 0L)
        val now = System.currentTimeMillis()
        if (existingCallId == callId && now - existingTs in 0 until GUARD_TTL_MS) {
            Log.i(TAG, "Duplicate incoming blocked callId=$callId")
            return false
        }
        prefs.edit()
            .putString(GUARD_CALL_ID_KEY, callId)
            .putLong(GUARD_TS_KEY, now)
            .apply()
        return true
    }

    private fun clearGuard(context: Context, callId: String) {
        val prefs = context.getSharedPreferences(GUARD_PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(GUARD_CALL_ID_KEY, null)
        if (existing != null && existing != callId) return
        prefs.edit().remove(GUARD_CALL_ID_KEY).remove(GUARD_TS_KEY).apply()
    }

    private fun isGuardActive(context: Context, callId: String): Boolean {
        if (callId.isBlank()) return false
        val prefs = context.getSharedPreferences(GUARD_PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(GUARD_CALL_ID_KEY, null) ?: return false
        if (existing != callId) return false
        val ts = prefs.getLong(GUARD_TS_KEY, 0L)
        val now = System.currentTimeMillis()
        val age = now - ts
        return age in 0 until GUARD_TTL_MS
    }
}
