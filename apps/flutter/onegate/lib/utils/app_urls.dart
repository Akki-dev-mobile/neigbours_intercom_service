import 'package:flutter/foundation.dart';
import 'dart:developer';

/// Centralized API URL manager
class ApiUrls {
  // Environment configuration
  static String? _environment;

  /// Set the environment manually (optional)
  static void setEnvironment(String env) {
    _environment = env.toLowerCase();
  }

  /// Get the current environment
  static String get currentEnvironment {
    return _environment ?? (kDebugMode ? 'staging' : 'production');
  }

  /// Get the appropriate gate base URL based on environment
  static String get gateBaseUrl {
    final env = currentEnvironment;
    String url;

    switch (env) {
      case 'staging':
      case 'stg':
      case 'dev':
      case 'development':
        url = "https://gateapi.cubeone.in/api";
        break;
      case 'production':
      case 'prod':
      default:
        url = "https://gateapi.cubeone.in/api";
        break;
    }

    log('🌐 ApiUrls.gateBaseUrl: Environment=$env, URL=$url');
    return url;
  }

  static String get societyBaseUrl => 'https://societybackend.cubeone.in/api';
  static String get facerecinfoUrl =>
      'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/gate_facial_e7e469b505.json';

  // Gate API Endpoints
  static String get gateLogin => '$gateBaseUrl/gatelogin';

  static String get gates => '$gateBaseUrl/admin/gates';

  static String get visitorEntry => '$gateBaseUrl/visitor/entry';

  static String get visitorLog => '$gateBaseUrl/visitor/log';

  static String get visitorCheckout => '$gateBaseUrl/visitor/checkout';

  static String get visitorSendLogs => '$gateBaseUrl/visitor/sendLogs';

  static String get readStatus => '$gateBaseUrl/visitor/requestApproval';

  static String get visitorGetLog => '$gateBaseUrl/visitor/getLog';

  // New v2 API endpoint for visitor logs with pagination and counts
  static String get visitorGetLogV2 => '$gateBaseUrl/v2/visitor/log';

  static String get visitorApprovals => '$gateBaseUrl/visitor/approvals';

  /// Request gate access / callback (Ready to Roll form)
  static String get requestGateAccess => '$gateBaseUrl/visitor/requestAccess';

  static String get verifyGuestPasscode => '$gateBaseUrl/member/pass/verify';

  /// Forgot password: request reset link (sends email via backend/Keycloak).
  static String get forgotPassword => '$gateBaseUrl/auth/forgot-password';

  // Society API Endpoints
  static String get buildingList => '$societyBaseUrl/admin/building/list';

  static String get memberList => '$societyBaseUrl/v2/admin/member/list';

  static String get unitList => '$societyBaseUrl/admin/units/list';

  static String get staffList => '$societyBaseUrl/admin/staffs/staffLists';

  /// Utility method to get current environment info
  static Map<String, String> getEnvironmentInfo() {
    return {
      'environment': currentEnvironment,
      'gateBaseUrl': gateBaseUrl,
      'isDebugMode': kDebugMode.toString(),
      'isManualOverride': (_environment != null).toString(),
    };
  }

  /// Reset environment to default (based on debug mode)
  static void resetEnvironment() {
    _environment = null;
    log('🔄 ApiUrls: Environment reset to default (${currentEnvironment})');
  }
}
