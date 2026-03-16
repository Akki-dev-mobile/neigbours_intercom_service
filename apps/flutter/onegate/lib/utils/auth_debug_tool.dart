import 'dart:developer';

/// Minimal auth debug tool so build and callers (AuthDebugWidget, AuthTestHelper) compile.
/// Replace with full diagnostics when needed.
class AuthDebugTool {
  static Future<Map<String, dynamic>> runDiagnostics() async {
    return {
      'summary': {
        'issues': <String>[],
      },
    };
  }

  static void printDiagnosticsReport(Map<String, dynamic> results) {
    log('AuthDebugTool report: $results');
  }
}
