import 'package:flutter/material.dart';
import 'package:intercom_module/intercom_module.dart';

void main() {
  // Demo configuration. For real apps, supply real tokens + societyId.
  IntercomModule.configure(
    IntercomModuleConfig.cubeOne(
      authPort: _DemoAuthPort(),
      contextPort: _DemoContextPort(),
      uploadPort: _DemoUploadPort(),
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intercom Module Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Intercom Module Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This example configures IntercomModuleConfig.cubeOne(...) and opens IntercomScreen.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IntercomScreen(fromNeighborsCard: true),
                  ),
                );
              },
              child: const Text('Open Neighbors (IntercomScreen)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IntercomScreen(fromNeighborsCard: false),
                  ),
                );
              },
              child: const Text('Open Intercom (IntercomScreen)'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: This demo uses a dummy JWT and societyId=1.\n'
              'Replace _DemoAuthPort/_DemoContextPort with real implementations in your app.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAuthPort implements IntercomAuthPort {
  // Syntactically valid "alg=none" JWT (JwtDecoder does not verify signature).
  static const String _dummyJwt =
      'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.'
      'eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJvbGRfZ2F0ZV91c2VyX2lkIjoxLCJ1c2VyX2lkIjoxLCJleHAiOjQxMDI0NDQ4MDB9.';

  @override
  Future<IntercomAuthTokens?> getTokens() async {
    return const IntercomAuthTokens(
      accessToken: _dummyJwt,
      idToken: _dummyJwt,
    );
  }
}

class _DemoContextPort implements IntercomContextPort {
  @override
  Future<int?> getSelectedSocietyId() async => 1;

  @override
  Future<String?> getCurrentUserUuid() async =>
      '00000000-0000-0000-0000-000000000000';

  @override
  Future<int?> getCurrentUserNumericId() async => 1;
}

class _DemoUploadPort implements IntercomUploadPort {
  @override
  Future<String?> uploadImage({
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    // Implement app-specific upload and return the public URL.
    return null;
  }
}
