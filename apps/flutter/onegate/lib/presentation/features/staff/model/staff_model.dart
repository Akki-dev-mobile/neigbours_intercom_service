class Staff {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String countryCode;
  final DateTime? dateOfBirth;
  final String category;
  final String categoryValue;
  final String gender;
  final String qualification;
  final String idProofType;
  final String idProofNumber;
  final String address;
  final String idProofImageUrl;
  final String profileImageUrl;

  Staff({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.dateOfBirth,
    required this.category,
    required this.categoryValue,
    required this.gender,
    required this.qualification,
    required this.idProofType,
    required this.idProofNumber,
    required this.address,
    required this.idProofImageUrl,
    required this.profileImageUrl,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['staff_email_id'] ?? '',
      phone: json['staff_contact_number'] ?? '',
      countryCode: json['country_code'] ?? 'IN',
      dateOfBirth: json['staff_dob'] != null
          ? DateTime.tryParse(json['staff_dob'])
          : null,
      category: json['category'] ?? '',
      categoryValue: json['categoryValue'] ?? '',
      gender: json['staff_gender'] ?? '',
      qualification: json['staff_qualification'] ?? '',
      idProofType: json['id_proof_type'] ?? '',
      idProofNumber: json['staff_badge_number'] ?? '',
      address: json['staff_address_1'] ?? '',
      idProofImageUrl: json['staff_proof'] ?? '',
      profileImageUrl: json['staff_image'] ?? '',
    );
  }

  @override
  String toString() {
    return 'Staff{id: $id, name: $name, email: $email, phone: $phone, countryCode: $countryCode, dateOfBirth: $dateOfBirth, category: $category, categoryValue: $categoryValue, gender: $gender, qualification: $qualification, idProofType: $idProofType, idProofNumber: $idProofNumber, address: $address, idProofImageUrl: $idProofImageUrl, profileImageUrl: $profileImageUrl}';
  }
}
