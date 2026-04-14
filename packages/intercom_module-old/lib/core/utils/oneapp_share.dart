import 'package:share_plus/share_plus.dart';
import '../storage/storage_service.dart';

class OneAppShare {
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  static Future<void> shareInvite({required String name}) async {
    final storage = StorageService.instance;
    final rawSocietyName = await storage.getString('society_name');
    final societyName = (rawSocietyName == null || rawSocietyName.trim().isEmpty)
        ? 'your society'
        : rawSocietyName.trim();

    final message = [
      'Hi Invite $name,',
      '',
      'You are invited to join "$societyName" on oneapp.',
      'Oneapp is the official platform for society updates, payments, and community communication.',
      '',
      '📱 Download oneapp:',
      '• Android: https://play.google.com/store/apps/details?id=com.cubeone.app&pcampaignid=web_share',
      '• iOS: https://apps.apple.com/in/app/oneapp-society-payments/id1492930711',
      '',
      'Install now to stay connected and access all society services in one place.',
    ].join('\n');

    await shareText(message);
  }
}
