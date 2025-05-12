# Network Logging System with Simple Timer

A comprehensive network logging system for the OneGate Flutter app that captures Dio requests, stores logs locally using Hive, and syncs them to a backend server using a simple Timer.

## Features

- **Network Log Capture**: Intercepts all Dio requests and stores them locally
- **Local Storage**: Uses Hive to store logs with metadata
- **Background Sync**: Syncs logs to a server every 2 minutes using a simple Timer
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

### 3. Server Setup

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

## Notes

- The network logging system only works in debug mode (`kDebugMode`)
- Logs are automatically synced to the server every 2 minutes
- The system includes metadata about which gate the logs are coming from
- Logs are batched when sending to the server (max 100 per request)

## Limitations of the Simple Timer Approach

The simple Timer approach has some limitations compared to using WorkManager or AlarmManager:

1. **Background Execution**: The Timer will only run when the app is in the foreground. It will not run when the app is in the background or closed.
2. **Battery Optimization**: The Timer does not respect battery optimization settings.
3. **Device Restart**: The Timer will not persist across device restarts.

However, for most use cases, this approach is sufficient, especially for debug-only features like network logging.

## Server API

The server API has the following endpoints:

- `POST /logs`: Send logs to the server
- `GET /logs`: Get logs from the server with optional filtering by gateId and environment
