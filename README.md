# neigbours_intercom_service

Reusable **Neighbours + Guard Intercom** Flutter package (UI, chat, calls, groups). Host apps inject auth, context, and API base URLs via ports—see `lib/src/ports/intercom_ports.dart`.

## Integration

**1. Dependency**

```yaml
dependencies:
  neigbours_intercom_service:
    path: ../neigbours_intercom_service # or git URL
```

**2. Configure before any navigation into the module**

```dart
import 'package:neigbours_intercom_service/intercom_module.dart';

void main() {
  IntercomModule.configure(
    IntercomModuleConfig.withEndpoints(
      authPort: MyAuthPort(),
      contextPort: MyContextPort(),
      endpoints: const IntercomEndpoints(
        societyBackendBaseUrl: 'https://your.api/society',
        apiGatewayBaseUrl: 'https://your.api/gateway',
        gateApiBaseUrl: 'https://your.api/gate',
        roomServiceBaseUrl: 'https://your.api/rooms',
        callServiceBaseUrl: 'https://your.api/calls',
        jitsiServerUrl: 'meet.your.domain',
      ),
      uploadPort: MyUploadPort(), // optional, for image uploads
    ),
  );
  runApp(const MyApp());
}
```

For the legacy CubeOne preset only, you can still use `IntercomModuleConfig.cubeOne(...)`.

**3. Open screens**

```dart
import 'package:neigbours_intercom_service/intercom_module.dart';

// Intercom (tabs: residents, committee, gatekeepers, …)
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const IntercomScreen(fromNeighborsCard: true),
  ),
);

// Neighbours hub (Groups / Residents / Committee)
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NeighbourScreen()),
);
```

Or use helpers: `pushIntercomScreen`, `pushNeighboursScreen` from `neighbours_api.dart` (exported from `intercom_module.dart`).

## Layout

- `lib/intercom/` — Intercom UI (tabs, chat, calls, widgets)
- `lib/neighbours/` — Neighbours hub screen + config + navigation helpers
- `lib/models/` — Domain models (calls, rooms, contacts, …)
- `lib/services/` — API + WebSocket + call managers
- `lib/core/` — Shared theme, API clients, widgets, utilities
- `lib/society_feed/` — Post/upload helpers
- `lib/src/` — `IntercomModule` config, Riverpod stubs, ports

## Manual steps after clone

- Run `flutter pub get` in this package and in `example/`.
- Replace demo JWT / society ids in `example/lib/main.dart` with real ports.
- Optionally add `analysis_options.yaml` rules to tune lint noise on legacy files.
