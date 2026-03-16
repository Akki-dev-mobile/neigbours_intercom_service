class Gate {
  int? id;
  int? companyId;
  String? gateName;
  String? gateType;
  int? userId;
  int? oldSsoUserId;

  int? status;
  String? tag;
  String? createdAt;
  String? updatedAt;
  bool isSelected;

  Gate({
    this.id,
    this.companyId,
    this.gateName,
    this.gateType,
    this.userId,
    this.oldSsoUserId,
    this.status,
    this.tag,
    this.createdAt,
    this.updatedAt,
    this.isSelected = false,
  });

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Gate.fromJson(Map<String, dynamic> json) {
    return Gate(
      id: json['id'],
      companyId: json['company_id'],
      gateName: json['gate_name'],
      gateType: json['gate_type'],
      userId: _parseInt(json['gate_user_id']),
      oldSsoUserId: _parseInt(json['old_sso_user_id']),
      status: json['status'],
      tag: json['tag'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'gate_name': gateName,
      'gate_type': gateType,
      'gate_user_id': userId,
      'old_sso_user_id': oldSsoUserId,
      'status': status,
      'tag': tag,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() {
    return 'Gate(id: $id, companyId: $companyId, gateName: $gateName, gateType: $gateType, userId: $userId, status: $status, tag: $tag, createdAt: $createdAt, updatedAt: $updatedAt,)';
  }
}
