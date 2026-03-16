class GateConfig {
  final String gateBaseUrl;
  /// When true, login screen uses native username/password form and backend auth.
  /// When false, login uses Keycloak WebView (AuthService.login).
  final bool useNativeLogin;

  GateConfig({
    required this.gateBaseUrl,
    this.useNativeLogin = true,
  });

  factory GateConfig.fromJson(Map<String, dynamic> json) {
    return GateConfig(
      gateBaseUrl: json['gate_base_domain'] ?? '',
      useNativeLogin: json['use_native_login'] as bool? ?? true,
    );
  }
}
