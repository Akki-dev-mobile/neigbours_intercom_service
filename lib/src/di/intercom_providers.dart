import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ports/intercom_ports.dart';

final intercomAuthPortProvider = Provider<IntercomAuthPort>((ref) {
  throw UnimplementedError(
    'Provide IntercomAuthPort via ProviderScope overrides.',
  );
});

final intercomContextPortProvider = Provider<IntercomContextPort>((ref) {
  throw UnimplementedError(
    'Provide IntercomContextPort via ProviderScope overrides.',
  );
});

final intercomEndpointsProvider = Provider<IntercomEndpoints>((ref) {
  throw UnimplementedError(
    'Provide IntercomEndpoints via ProviderScope overrides.',
  );
});

final intercomHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
