# Network Logging System

A comprehensive network logging system for the OneGate Flutter app that captures Dio requests, stores logs locally using Hive, and syncs them to a backend server.

## Features

- **Network Log Capture**: Intercepts all Dio requests and stores them locally
- **Local Storage**: Uses Hive to store logs with metadata
- **Background Sync**: Syncs logs to a server every 2 minutes using android_alarm_manager_plus
- **Server Integration**: Includes a Node.js + Express API with MongoDB integration
- **UI**: Provides screens to view logs and configure sync settings

## Setup

### 1. Dependencies

Make sure you have the following dependencies in your `pubspec.yaml`:

```yaml
dependencies:
  dio: ^4.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  android_alarm_manager_plus: ^3.0.4
  shared_preferences: ^2.5.3

dev_dependencies:
  build_runner: ^2.4.8
  hive_generator: ^2.0.1
```

### 2. Generate Hive Adapters

Run the following command to generate the Hive adapters:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Update AndroidManifest.xml

Add the following permissions and services to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<application>
    <!-- Add these services for android_alarm_manager_plus -->
    <service
        android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
        android:exported="false"
        android:permission="android.permission.BIND_JOB_SERVICE" />
    <receiver
        android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
        android:exported="false" />
    <receiver
        android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
        android:enabled="false"
        android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
        </intent-filter>
    </receiver>
</application>
```

### 4. Server Setup

1. Navigate to the `server` directory
2. Install dependencies: `npm install`
3. Create a `.env` file based on `.env.example`
4. Start the server: `npm start`

## Usage

### Initialize the Network Log Manager

In your app's initialization code (e.g., `main.dart`):

```dart
import 'package:flutter_onegate/utils/network_log/network_log_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize NetworkLogManager
  await NetworkLogManager().initialize();
  
  // Initialize AndroidAlarmManager
  await AndroidAlarmManager.initialize();
  
  // Add network logger interceptor to your Dio instance
  final dio = Dio();
  NetworkLogManager().addInterceptorToDio(dio);
  
  // Set the gate ID
  await NetworkLogManager().updateGateId('MAIN_GATE');
  
  // Rest of your initialization code
  runApp(MyApp());
}
```

### View Network Logs

Use the `NetworkLogScreen` to view captured logs:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NetworkLogScreen(),
  ),
);
```

### Configure Sync Settings

Use the `NetworkLogSyncSettings` screen to configure sync settings:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NetworkLogSyncSettings(),
  ),
);
```

### Manual Sync

Trigger a manual sync:

```dart
await NetworkLogManager().triggerManualSync();
```

## Testing

Use the `NetworkLogTestPage` to test the network logging functionality:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NetworkLogTestPage(),
  ),
);
```

## Notes

- The network logging system only works in debug mode (`kDebugMode`)
- Logs are automatically synced to the server every 2 minutes
- The system includes metadata about which gate the logs are coming from
- Logs are batched when sending to the server (max 100 per request)
