class Gate {
  int? id;
  int? companyId;
  String? gateName;
  String? gateType;
  int? userId;
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
    this.status,
    this.tag,
    this.createdAt,
    this.updatedAt,
    this.isSelected = false,
  });

  factory Gate.fromJson(Map<String, dynamic> json) {
    return Gate(
      id: json['id'],
      companyId: json['company_id'],
      gateName: json['gate_name'],
      gateType: json['gate_type'],
      userId: json['user_id'],
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
      'user_id': userId,
      'status': status,
      'tag': tag,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
