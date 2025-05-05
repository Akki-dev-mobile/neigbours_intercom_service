/// Centralized API URL manager
class ApiUrls {
  static String get gateBaseUrl =>
      // "https://2ea3-103-178-133-37.ngrok-free.app/api";

  "https://stggateapi.cubeone.in/api";

  // GateConfigHolder.gateBaseUrl;

  static String get societyBaseUrl => 'https://socbackend.cubeone.in/api';
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

  static String get visitorApprovals => '$gateBaseUrl/visitor/approvals';

  static String get verifyGuestPasscode => '$gateBaseUrl/member/pass/verify';

  // Society API Endpoints
  static String get buildingList => '$societyBaseUrl/admin/building/list';

  static String get memberList => '$societyBaseUrl/admin/member/list';

  static String get unitList => '$societyBaseUrl/admin/units/list';

  static String get staffList => '$societyBaseUrl/admin/staffs/staffLists';
}
