class PurposeCategory1 {
  final int categoryId;
  final String categoryName;
  final String? image;
  List<SubCategory>? subCategories;
  bool isSelected;

  PurposeCategory1({
    required this.categoryId,
    required this.categoryName,
    this.image,
    this.subCategories,
    this.isSelected = false,
  });

  factory PurposeCategory1.fromJson(Map<String, dynamic> json) {
    return PurposeCategory1(
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      image: json['category_img'],
      subCategories: json['sub_categories'] != null
          ? (json['sub_categories'] as List<dynamic>)
          .map((sub) => SubCategory.fromJson(sub))
          .toList()
          : null,
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'category_name': categoryName,
      'category_img': image,
      'sub_categories': subCategories?.map((sub) => sub.toJson()).toList(),
      'isSelected': isSelected,
    };
  }
}

class SubCategory {
  final int? subCategoryId;
  final String? subCategoryName;
  final String? image;
  bool isSelected;

  SubCategory({
    required this.subCategoryId,
    required this.subCategoryName,
    this.image,
    this.isSelected = false,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      subCategoryId: json['sub_category_id'],
      subCategoryName: json['sub_category_name'],
      image: json['sub_category_purpose_img'],
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sub_category_id': subCategoryId,
      'sub_category_name': subCategoryName,
      'sub_category_purpose_img': image,
      'isSelected': isSelected,
    };
  }
}