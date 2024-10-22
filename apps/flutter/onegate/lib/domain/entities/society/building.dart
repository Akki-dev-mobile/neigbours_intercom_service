class Building {
  int id;
  int socId;
  dynamic vizlogBuildingId;
  dynamic socBuildingName;
  dynamic socBuildingFloors;
  int unitsPerFloor;
  dynamic cancelDate;
  dynamic cancellationReason;
  int status;
  dynamic createdDate;
  dynamic createdBy;
  dynamic updatedDate;
  dynamic updatedBy;

  Building({
    required this.id,
    required this.socId,
    required this.vizlogBuildingId,
    required this.socBuildingName,
    required this.socBuildingFloors,
    required this.unitsPerFloor,
    required this.cancelDate,
    required this.cancellationReason,
    required this.status,
    required this.createdDate,
    required this.createdBy,
    required this.updatedDate,
    required this.updatedBy,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['id'],
      socId: json['soc_id'],
      vizlogBuildingId: json['vizlog_building_id'],
      socBuildingName: json['soc_building_name'],
      socBuildingFloors: json['soc_building_floors'],
      unitsPerFloor: json['units_per_floor'],
      cancelDate: json['cancel_date'],
      cancellationReason: json['cancellation_reason'],
      status: json['status'],
      createdDate: json['created_date'],
      createdBy: json['created_by'],
      updatedDate: json['updated_date'],
      updatedBy: json['updated_by'],
    );
  }

  static List<Building> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => Building.fromJson(json)).toList();
  }
}
