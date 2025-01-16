class PurposeCategory1 {
  final int categoryId;
  final String categoryName;
  final String? image; // Nullable field for image URL
  final List<SubCategory>? subCategories; // Nullable list of subcategories
  bool isSelected; // Field to track selection

  PurposeCategory1({
    required this.categoryId,
    required this.categoryName,
    this.image,
    this.subCategories,
    this.isSelected = false, // Default to false
  });

  factory PurposeCategory1.fromJson(Map<String, dynamic> json) {
    return PurposeCategory1(
      categoryId: json['category_id'] ?? 0,
      categoryName: json['purpose_category_name'] ?? '',
      image: json['image'],
      subCategories: json['sub_categories'] != null
          ? (json['sub_categories'] as List<dynamic>)
          .map((sub) => SubCategory.fromJson(sub))
          .toList()
          : null,
      isSelected: json['isSelected'] ?? false, // Handle isSelected
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'purpose_category_name': categoryName,
      'image': image,
      'sub_categories': subCategories?.map((sub) => sub.toJson()).toList(),
      'isSelected': isSelected,
    };
  }
}

class SubCategory {
  final int? subCategoryId;
  final String? subCategoryName;
  final String? image; // Nullable field for image URL in subcategories
  bool isSelected; // Field to track selection

  SubCategory({
    required this.subCategoryId,
    required this.subCategoryName,
    this.image,
    this.isSelected = false, // Default to false
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      subCategoryId: json['sub_category_id'],
      subCategoryName: json['purpose_sub_category_name'],
      image: json['image'], // Handle nullability of the image field
      isSelected: json['isSelected'] ?? false, // Handle isSelected
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sub_category_id': subCategoryId,
      'purpose_sub_category_name': subCategoryName,
      'image': image,
      'isSelected': isSelected,
    };
  }
}