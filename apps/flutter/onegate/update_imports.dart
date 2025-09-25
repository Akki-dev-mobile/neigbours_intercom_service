import 'dart:io';

void main() {
  final files = [
    'lib/splash_screen.dart',
    'lib/main.dart',
    'lib/presentation/features/gate_selection/ui/gate_selection_view.dart',
    'lib/presentation/features/visitor_checkin_flow/visitor_in_screens/ui/request_permission_page.dart',
    'lib/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart',
    'lib/presentation/features/visitor_checkin_flow/units_selection/ui/unit_selection_view.dart',
    'lib/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart',
    'lib/presentation/features/settings/pages/network_logs_dashboard.dart',
    'lib/presentation/features/settings/pages/visitor_settings.dart',
    'lib/presentation/features/settings/pages/settings_home.dart',
    'lib/presentation/features/settings/pages/app_permissions.dart',
    'lib/presentation/features/self_entry/ui/passcode_entry_view.dart',
    'lib/presentation/features/self_entry/ui/self_profile_view.dart',
    'lib/presentation/features/settings/crash_reports_screen.dart',
    'lib/presentation/features/settings/analytics_dashboard_screen.dart',
    'lib/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart',
    'lib/presentation/features/auth/pages/login_view.dart',
    'lib/presentation/widgets/advanced_search_widget.dart',
  ];

  for (final file in files) {
    final content = File(file).readAsStringSync();
    final updatedContent = content.replaceAll(
      "import 'package:flutter_onegate/generated/l10n/app_localizations.dart';",
      "import '${_getRelativePath(file)}generated/l10n/app_localizations.dart';",
    );
    File(file).writeAsStringSync(updatedContent);
  }
}

String _getRelativePath(String filePath) {
  final parts = filePath.split('/');
  final depth = parts.length - 2; // -2 for 'lib' and the file itself
  return '../' * depth;
} 