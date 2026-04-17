# flutter_onegate

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android Incoming Call Flow

- Incoming call invites must be sent as Android data-only FCM payloads. Do not rely on the `notification` block for call invites, or full-screen locked-screen delivery becomes unreliable.
- Required payload keys for `action: incoming_call`: `call_id`, `call_type` (`audio` or `video`), `caller_name`, `caller_phone`, `meeting_id`, `jitsi_url`, and optional `image`.
- Lifecycle behavior:
  - Foreground: `FirebaseMessaging.onMessage` routes the payload into `PushNotificationService`, which runs duplicate guards, updates `CallCoordinator`, and shows `flutter_callkit_incoming`.
  - Background: `FirebaseMessaging.onBackgroundMessage` does the same from the background isolate, so Android can still raise the full-screen incoming UI.
  - Resume/replay: `onMessageOpenedApp` and `getInitialMessage` feed the same coordinator path for fallback delivery after process/app resume.
  - Locked screen: Android CallKit uses `isShowFullLockedScreen: true` with the `Incoming Calls` channel so the incoming UI can appear over the lock screen.
