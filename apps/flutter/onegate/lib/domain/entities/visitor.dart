class Visitor {
  late int? visitorId;
  late int? userId;
  late int? companyId;
  late int? unitId;
  late String? firstName;
  late String? lastName;
  late String? gender;
  late String? dob;
  late String? mobile;
  late String? email;
  late String? imagePath;
  late String? comingFrom;
  late String? city;
  late String? state;
  late String? country;
  late String? visitorType;
  late String? idProof;
  late String? idProofType;
  late String? idProofImage;
  late String? idProofImagePath;
  late String? passSerialNo;
  late String? visitorCode;
  late String? passType;
  late String? passStartDate;
  late String? passEndDate;
  late int? passValidity;
  late String? cardNo;
  late int? status;
  late String? category;
  late int? isLogVisible;
  late int? createdBy;
  late String? createdAt;
  late Object? updatedBy;
  late String? updatedAt;
  late String? purpose;
  late int? buildingUnitId;
  late String? imageLarge;
  late String? imageMedium;
  late String? imageSmall;
  late String? isoCode;
  late String? dialCode;
  late String? staffType;

  Visitor({
    this.visitorId,
    this.userId,
    this.companyId,
    this.unitId,
    this.firstName,
    this.lastName,
    this.gender,
    this.dob,
    this.mobile,
    this.email,
    this.imagePath,
    this.comingFrom,
    this.city,
    this.state,
    this.country,
    this.visitorType,
    this.idProof,
    this.idProofType,
    this.idProofImage,
    this.idProofImagePath,
    this.passSerialNo,
    this.visitorCode,
    this.passType,
    this.passStartDate,
    this.passEndDate,
    this.passValidity,
    this.cardNo,
    this.status,
    this.category,
    this.isLogVisible,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.purpose,
    this.buildingUnitId,
    this.imageLarge,
    this.imageMedium,
    this.imageSmall,
    this.isoCode,
    this.dialCode,
    this.staffType,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    // Convert JSON to fields
    return Visitor(
      visitorId: json['visitorId'],
      userId: json['userId'],
      companyId: json['companyId'],
      unitId: json['unitId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      gender: json['gender'],
      dob: json['dob'],
      mobile: json['mobile'],
      email: json['email'],
      imagePath: json['imagePath'],
      comingFrom: json['comingFrom'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      visitorType: json['visitorType'],
      idProof: json['idProof'],
      idProofType: json['idProofType'],
      idProofImage: json['idProofImage'],
      idProofImagePath: json['idProofImagePath'],
      passSerialNo: json['passSerialNo'],
      visitorCode: json['visitorCode'],
      passType: json['passType'],
      passStartDate: json['passStartDate'],
      passEndDate: json['passEndDate'],
      passValidity: json['passValidity'],
      cardNo: json['cardNo'],
      status: json['status'],
      category: json['category'],
      isLogVisible: json['isLogVisible'],
      createdBy: json['createdBy'],
      createdAt: json['createdAt'],
      updatedBy: json['updatedBy'],
      updatedAt: json['updatedAt'],
      purpose: json['purpose'],
      buildingUnitId: json['buildingUnitId'],
      imageLarge: json['imageLarge'],
      imageMedium: json['imageMedium'],
      imageSmall: json['imageSmall'],
      isoCode: json['isoCode'],
      dialCode: json['dialCode'],
      staffType: json['staffType'],
    );
  }
    

  Map<String, dynamic> toJson() {
    return {
        'visitorId': visitorId,
        'userId': userId,
        'companyId': companyId,
        'unitId': unitId,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'dob': dob,
        'mobile': mobile,
        'email': email,
        'imagePath': imagePath,
        'comingFrom': comingFrom,
        'city': city,
        'state': state,
        'country': country,
        'visitorType': visitorType,
        'idProof': idProof,
        'idProofType': idProofType,
        'idProofImage': idProofImage,
        'idProofImagePath': idProofImagePath,
        'passSerialNo': passSerialNo,
        'visitorCode': visitorCode,
        'passType': passType,
        'passStartDate': passStartDate,
        'passEndDate': passEndDate,
        'passValidity': passValidity,
        'cardNo': cardNo,
        'status': status,
        'category': category,
        'isLogVisible': isLogVisible,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt,
        'purpose': purpose,
        'buildingUnitId': buildingUnitId,
        'imageLarge': imageLarge,
        'imageMedium': imageMedium,
        'imageSmall': imageSmall,
        'isoCode': isoCode,
        'dialCode': dialCode,
        'staffType': staffType,
      };
  }
}
