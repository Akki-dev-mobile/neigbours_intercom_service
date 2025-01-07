class VisitorMapper {
  VisitorMapper({
    this.id,
    this.name,
    this.mobile,
    this.VisitorMapperImage,
    this.comingFrom,
    this.cardNumber,
    this.guestCount, // New field for guest count
  });

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String? name;
  String? mobile;
  String? VisitorMapperImage; // Visitor image URL or path
  String? comingFrom; // Information about where the visitor is coming from
  String? cardNumber; // New field for card number
  int? guestCount; // New field for the number of guests

  /// Factory constructor to create a `VisitorMapper` object from JSON.
  factory VisitorMapper.fromJson(Map<String, dynamic> json) {
    return VisitorMapper(
      id: json['id'] as int?, // Handle nullable id
      name: json['name'] as String?, // Handle nullable name
      mobile: json['mobile'] as String?, // Handle nullable mobile
      VisitorMapperImage: json['visitor_image'] as String?, // Handle nullable visitorImage
      comingFrom: json['coming_from'] as String?, // Handle nullable comingFrom
      cardNumber: json['card_number'] as String?, // Handle nullable cardNumber
      guestCount: json['guest_count'] as int?, // Handle nullable guestCount
    );
  }

  /// Converts the `VisitorMapper` object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'visitor_image': VisitorMapperImage,
      'coming_from': comingFrom,
      'card_number': cardNumber,
      'guest_count': guestCount, // Include guest count in JSON
    };
  }
}