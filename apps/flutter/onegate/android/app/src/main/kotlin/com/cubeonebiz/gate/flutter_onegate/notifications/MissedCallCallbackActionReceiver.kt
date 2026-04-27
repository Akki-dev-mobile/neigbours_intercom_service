package com.cubeonebiz.gate.flutter_onegate.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

class MissedCallCallbackActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "MissedCallCallbackRx"
        private const val PREFS = "FlutterSharedPreferences"
        private const val PENDING_CALLBACK_KEY = "flutter.pending_call_callback_v1"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            val data = JSONObject().apply {
                put("call_id", intent.getStringExtra("call_id") ?: "")
                put("caller_name", intent.getStringExtra("caller_name") ?: "")
                put("caller_phone", intent.getStringExtra("caller_phone") ?: "")
                put("caller_user_id", intent.getStringExtra("caller_user_id") ?: "")
                put("from_user_id", intent.getStringExtra("from_user_id") ?: "")
                put("image", intent.getStringExtra("image") ?: "")
                put("meeting_id", intent.getStringExtra("meeting_id") ?: "")
                put("meetingId", intent.getStringExtra("meetingId") ?: "")
                put("jitsi_url", intent.getStringExtra("jitsi_url") ?: "")
                put("jitsi_meeting_url", intent.getStringExtra("jitsi_meeting_url") ?: "")
                put("callback_action", "notification_tap")
            }
            val envelope = JSONObject().apply {
                put("ts_ms", System.currentTimeMillis())
                put("data", data)
            }
            context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(PENDING_CALLBACK_KEY, envelope.toString())
                .apply()

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP,
                    )
                }
            if (launchIntent != null) {
                context.startActivity(launchIntent)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Failed handling callback action", t)
        }
    }
}
