import 'package:onegate_client/onegate_client.dart';

import 'domain/entities/visitor/purpose/purpose.dart';

class PurposeCategoryMapper {
  // Convert a single JSON object to a PurposeCategory
  static PurposeCategory1 fromJson(Map<String, dynamic> json) {
    return PurposeCategory1(
      categoryId: json['id'],
      categoryName: json['purpose_category_name'] as String,
      image: json['purpose_img'] as String,
      // isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  // Convert a single PurposeCategory to JSON
  static Map<String, dynamic> toJson(PurposeCategory purposeCategory) {
    return {
      'id': purposeCategory.id,
      'purpose_category_name': purposeCategory.purpose_category_name,
      'purpose_img': purposeCategory.purpose_img,
      'isSelected': purposeCategory.isSelected,
    };
  }

  // Convert a list of JSON objects to a list of PurposeCategory
  static List<PurposeCategory1> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Convert a list of PurposeCategory to a list of JSON objects
  static List<Map<String, dynamic>> toJsonList(
      List<PurposeCategory> purposeCategories) {
    return purposeCategories.map((category) => toJson(category)).toList();
  }
}
