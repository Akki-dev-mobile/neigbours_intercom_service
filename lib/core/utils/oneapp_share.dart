import 'package:share_plus/share_plus.dart';

class OneAppShare {
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  static Future<void> shareInvite({required String name}) async {
    await shareText('Invite $name');
  }
}
