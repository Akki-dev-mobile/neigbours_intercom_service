import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/network_log.dart';
import 'test_network_log_capture.dart';

final FlutterI18nDelegate _networkLogTestI18nDelegate = FlutterI18nDelegate(
  translationLoader: FileTranslationLoader(
    basePath: 'assets/flutter_i18n',
    fallbackFile: 'en',
    useCountryCode: false,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register the NetworkLog adapter
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(NetworkLogAdapter());
  }
  
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => ctx.tr('networkLogTestAppTitle'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      localizationsDelegates: [
        AppLocalizations.delegate,
        _networkLogTestI18nDelegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('mr'),
      ],
      home: const TestNetworkLogCapture(),
    );
  }
}
