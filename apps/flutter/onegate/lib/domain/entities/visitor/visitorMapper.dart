class VisitorMapper {
  VisitorMapper({
    this.id,
    required this.name,
    required this.mobile,
    required this.VisitorMapperImage,
  });

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String name;
  String mobile;
  String VisitorMapperImage;

  /// Factory constructor to create a `VisitorMapper` object from JSON.
  factory VisitorMapper.fromJson(Map<String, dynamic> json) {
    return VisitorMapper(
      id: json['id'] as int?,
      name: json['name'] as String,
      mobile: json['mobile'] as String,
      VisitorMapperImage: json['VisitorMapper_image'] as String,
    );
  }

  /// Converts the `VisitorMapper` object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'VisitorMapper_image': VisitorMapperImage,
    };
  }
}