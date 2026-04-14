class GateModel {
  final int? gateId;
  final String? gateName;
  final String? gateType;
  final int? companyId;
  final List<GatekeeperModel> gatekeepers;

  const GateModel({
    this.gateId,
    this.gateName,
    this.gateType,
    this.companyId,
    this.gatekeepers = const [],
  });

  factory GateModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) => v == null ? null : int.tryParse(v.toString());

    final gatekeepersRaw = json['gatekeepers'];
    final gatekeepers = (gatekeepersRaw is List)
        ? gatekeepersRaw
            .whereType<Map>()
            .map((e) => GatekeeperModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <GatekeeperModel>[];

    return GateModel(
      gateId: parseInt(json['gate_id'] ?? json['id']),
      gateName: (json['gate_name'] ?? json['name'])?.toString(),
      gateType: (json['gate_type'] ?? json['type'])?.toString(),
      companyId: parseInt(json['company_id']),
      gatekeepers: gatekeepers,
    );
  }
}

class GatekeeperModel {
  final int? gatekeeperId;
  final String? gatekeeperName;
  final String? mobile;
  final String? designation;
  final bool? isActive;
  final String? profileImage;
  final String? id;

  const GatekeeperModel({
    this.gatekeeperId,
    this.gatekeeperName,
    this.mobile,
    this.designation,
    this.isActive,
    this.profileImage,
    this.id,
  });

  factory GatekeeperModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
    bool? parseBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return null;
    }

    return GatekeeperModel(
      gatekeeperId: parseInt(json['gatekeeper_id'] ?? json['id']),
      gatekeeperName: (json['gatekeeper_name'] ?? json['name'])?.toString(),
      mobile: (json['mobile'] ?? json['phone'])?.toString(),
      designation: (json['designation'] ?? json['role'])?.toString(),
      isActive: parseBool(json['is_active'] ?? json['active']),
      profileImage: (json['profile_image'] ?? json['image'])?.toString(),
      id: (json['gatekeeper_id'] ?? json['id'])?.toString(),
    );
  }
}
