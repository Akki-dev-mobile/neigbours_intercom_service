class Visitor {
  Visitor({
    this.id,
    this.name,
    this.mobile,
    this.visitor_image,
  });

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String? name;

  String? mobile;

  String? visitor_image;

  /// Convert the object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'visitor_image': visitor_image,
    };
  }

  /// Create an instance from a JSON map.
  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id'] as int?,
      name: json['name'] as String?,
      mobile: json['mobile'] as String?,
      visitor_image: json['visitor_image'] as String?,
    );
  }
}