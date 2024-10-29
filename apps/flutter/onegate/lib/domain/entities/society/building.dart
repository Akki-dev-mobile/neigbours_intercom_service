class Building {
  int? id;
  int? socId;
  dynamic vizlogBuildingId;
  dynamic socBuildingName;
  dynamic socBuildingFloors;
  int? unitsPerFloor;
  dynamic cancelDate;
  dynamic cancellationReason;
  int? status;
  dynamic createdDate;
  dynamic createdBy;
  dynamic updatedDate;
  dynamic updatedBy;

  Building({
    this.id,
    this.socId,
    this.vizlogBuildingId,
    this.socBuildingName,
    this.socBuildingFloors,
    this.unitsPerFloor,
    this.cancelDate,
    this.cancellationReason,
    this.status,
    this.createdDate,
    this.createdBy,
    this.updatedDate,
    this.updatedBy,
  });

  // Helper function to safely parse integers from dynamic types
  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: parseInt(json['id']),
      socId: parseInt(json['soc_id']),
      vizlogBuildingId: json['vizlog_building_id'],
      socBuildingName: json['soc_building_name'],
      socBuildingFloors: json['soc_building_floors'],
      unitsPerFloor: parseInt(json['units_per_floor']),
      cancelDate: json['cancel_date'],
      cancellationReason: json['cancellation_reason'],
      status: parseInt(json['status']),
      createdDate: json['created_date'],
      createdBy: json['created_by'],
      updatedDate: json['updated_date'],
      updatedBy: json['updated_by'],
    );
  }

  static List<Building> fromJsonList(List<Map<String, dynamic>> jsonList) {
    return jsonList.map((json) => Building.fromJson(json)).toList();
  }
}
