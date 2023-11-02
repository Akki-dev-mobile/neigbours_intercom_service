import 'package:image_picker/image_picker.dart';
import 'package:onegate_client/onegate_client.dart';

abstract class VisitorRepository {
  Future<Visitor?> searchVisitor(String mobileNumber);
  Future<List<PurposeCategory>?>? fetchPurposeCategory();
  Future<String?> uploadImage(XFile file, String userMobile, int companyId);
  Future<Visitor?> createVisitor(Visitor visitor);
}
