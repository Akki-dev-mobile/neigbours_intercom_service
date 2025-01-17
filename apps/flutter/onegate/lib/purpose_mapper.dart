import 'package:onegate_client/onegate_client.dart';

import 'domain/entities/visitor/purpose/purpose.dart';

class PurposeCategoryMapper {
  // Convert a single JSON object to a PurposeCategory
  static PurposeCategory1 fromJson(Map<String, dynamic> json) {
    return PurposeCategory1(
      categoryId: json['categr'],
      categoryName: json['purpose_category_name'] as String,
      image: json['purpose_img'] as String,
      // isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  // Convert a single PurposeCategory to JSON
  static Map<String, dynamic> toJson(PurposeCategory1 purposeCategory) {
    return {
      'id': purposeCategory.categoryId,
      'purpose_category_name': purposeCategory.categoryName,
      'purpose_img': purposeCategory.image,
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
      List<PurposeCategory1> purposeCategories) {
    return purposeCategories.map((category) => toJson(category)).toList();
  }
}
