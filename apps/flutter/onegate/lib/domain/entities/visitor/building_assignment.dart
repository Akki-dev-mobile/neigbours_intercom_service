class BuildingAssignment {
  BuildingAssignment({
    this.id,
    this.visitor_id,
    this.visitor_log_id,
    this.company_id,
    this.building_id,
    this.unit_id,
  });

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int? visitor_id;

  int? visitor_log_id;

  int? company_id;

  int? building_id;

  List<String>? unit_id;

  /// Convert the object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitor_id': visitor_id,
      'visitor_log_id': visitor_log_id,
      'company_id': company_id,
      'building_id': building_id,
      'unit_id': unit_id,
    };
  }

  /// Create an instance from a JSON map.
  factory BuildingAssignment.fromJson(Map<String, dynamic> json) {
    return BuildingAssignment(
      id: json['id'] as int?,
      visitor_id: json['visitor_id'] as int?,
      visitor_log_id: json['visitor_log_id'] as int?,
      company_id: json['company_id'] as int?,
      building_id: json['building_id'] as int?,
      unit_id: (json['unit_id'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
