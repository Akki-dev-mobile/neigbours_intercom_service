class VisitorMapper {
  VisitorMapper({
    this.id,
    this.name,
    this.mobile,
    this.VisitorMapperImage,
  });

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String? name;
  String? mobile;
  String? VisitorMapperImage; // All fields are now nullable

  /// Factory constructor to create a `VisitorMapper` object from JSON.
  factory VisitorMapper.fromJson(Map<String, dynamic> json) {
    return VisitorMapper(
      id: json['id'] as int?, // Handle nullable id
      name: json['name'] as String?, // Handle nullable name
      mobile: json['mobile'] as String?, // Handle nullable mobile
      VisitorMapperImage: json['visitor_image'] as String?, // Handle nullable visitorImage
    );
  }

  /// Converts the `VisitorMapper` object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'visitor_image': VisitorMapperImage,
    };
  }
}