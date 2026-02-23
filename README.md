# intercom_module

Reusable Intercom/Neighbors module extracted from this app, designed to be **plug-and-play** in other Flutter apps.

Key idea: the module does **not** own auth/session/environment. Host apps inject those through interfaces/providers.

## Integration (host app)

1) Add a path dependency:

```yaml
dependencies:
  intercom_module:
    path: packages/intercom_module
```

2) Configure the module (minimal required ports):

```dart
import 'package:intercom_module/intercom_module.dart';

void main() {
  IntercomModule.configure(
    IntercomModuleConfig(
      authPort: MyAuthPort(),
      contextPort: MyContextPort(),
      // Optional: provide if you want group/post image uploads to work.
      // uploadPort: MyUploadPort(),
      endpoints: const IntercomEndpoints(
        societyBackendBaseUrl: 'https://your-society-backend/api',
        apiGatewayBaseUrl: 'https://your-apigw/api',
        gateApiBaseUrl: 'https://your-gate-api/api',
        roomServiceBaseUrl: 'https://your-room-service/api/v1',
        callServiceBaseUrl: 'https://your-call-service/api',
        jitsiServerUrl: 'collab.yourdomain.com',
      ),
    ),
  );

  runApp(const MyApp());
}
```

3) Use the screen:

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const IntercomScreen(fromNeighborsCard: true),
  ),
);
```

## Ports you must implement

- `IntercomAuthPort`: provides access token(s) for API calls.
- `IntercomContextPort`: provides selected society/company id + current user identifiers.

See `lib/src/ports/intercom_ports.dart`.

## Notes

- The extracted module includes legacy UI + services; some integrations (like post image upload) are app-specific and may require host customization (`lib/modules/household/society_feed/services/post_api_client.dart`).
