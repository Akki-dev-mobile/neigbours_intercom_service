class GateConfig {
  final String gateBaseUrl;
  // final String societyBaseUrl;

  GateConfig({
    required this.gateBaseUrl,
    // required this.societyBaseUrl,
  });

  factory GateConfig.fromJson(Map<String, dynamic> json) {
    return GateConfig(
      gateBaseUrl: json['gate_base_domain'] ?? '',
      // societyBaseUrl: json['society_base_url'] ?? '',
    );
  }
}