// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/gate/gate2.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/app_permissions.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/configure_duty_alarms.dart';
import 'package:flutter_onegate/presentation/features/settings/data_observability_settings_screen.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/network_logs_dashboard.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_settings.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_home_view.dart';
import 'package:flutter_onegate/presentation/features/missed_approval/widget/time_provider.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:flutter_onegate/services/auth_service/auth_service.dart';
import 'package:flutter_onegate/services/auth_service/centralized_logout_service.dart';
import 'package:flutter_onegate/services/session_manager/session_management_coordinator.dart';
import 'package:flutter_onegate/services/language/language_provider.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../self_entry/self_home_view.dart';
import 'settings_gate.dart';

class SettingsHome extends StatefulWidget {
  const SettingsHome({super.key});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  String? _cameraValue;
  String? _languageValue;
  String? _visitorApprovalTimeValue;
  String? _dataStorageValue;
  String? selectedGate;
  final PreferenceUtils _preferenceUtils = GetIt.I<PreferenceUtils>();
  Gate? selectedGateObj;
  String? selectedGateName;
  String? cameraValue;
  final _flutterKioskMode = FlutterKioskMode.instance();

  // Temporary selection values for bottom sheets
  String? _tempCameraValue;
  int? _tempApprovalTimeValue;

  List<String> options = [
    'Gate 1',
    'Gate 2',
    'Gate 3',
    'Gate 4',
  ];

  @override
  void initState() {
    super.initState();
    selectedGateObj = _preferenceUtils.getSelectedGate();
    _preferenceUtils.getTooglevalue();
    getSelectedGate();
    getCameraValue();
    _initializeLanguage();
    _initializeRole();
  }

  void _initializeLanguage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        setState(() {
          _languageValue = languageProvider.currentLanguageName;
        });
      }
    });
  }

  void _enableKioskMode() async {
    try {
      await _flutterKioskMode.start();
    } catch (e) {
      print("Error starting kiosk mode: $e");
    }
  }

  void _showCameraSettings(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final cameraProvider =
                Provider.of<CameraSettingsProvider>(context, listen: false);
            final currentValue = cameraProvider.selectedCameraValue;

            // Initialize temp value if not set
            _tempCameraValue ??= currentValue;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced drag handle
                  const SizedBox(height: 12),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Enhanced header with gradient background
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xffF44336).withOpacity(0.08),
                          const Color(0xffff5722).withOpacity(0.03),
                        ],
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        // Compact icon section
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Simple label section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context).selectCamera,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff212427),
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)!
                                    .chooseCameraPreference,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(top: 16),
                        itemCount: _cameraItems.length,
                        itemBuilder: (context, index) {
                          final item = _cameraItems[index];
                          final isSelected = _tempCameraValue == item.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    _tempCameraValue = item.value;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffF44336)
                                          : Colors.grey[200]!,
                                      width: isSelected ? 1.0 : 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Camera icon with background
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          item.value == 'front'
                                              ? Icons.camera_front
                                              : Icons.camera_rear,
                                          color: const Color(0xffF44336),
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Camera information
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr(item.label),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xff212427),
                                                    fontSize: 18,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.value == 'front'
                                                  ? AppLocalizations.of(
                                                          context)!
                                                      .useFrontFacingCamera
                                                  : AppLocalizations.of(
                                                          context)!
                                                      .useRearFacingCamera,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xff57636C),
                                                    fontSize: 14,
                                                    height: 1.3,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Selection indicator - Checkbox
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xffF44336)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xffF44336)
                                                : const Color(0xff57636C),
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Confirm Button Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xffF44336),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xffF44336),
                                  width: 1,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              context.tr('Cancel'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff212427), Color(0xff57636C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _cameraValue = _tempCameraValue;
                                });
                                cameraProvider
                                    .updateCameraValue(_tempCameraValue!);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xff4CAF50),
                                            Color(0xff45A049),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xff4CAF50)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(context)!
                                                      .success,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  AppLocalizations.of(context)!
                                                      .cameraSettingUpdatedSuccessfully,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: Text(
                                context.tr('Confirm'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageSettings(BuildContext context) async {
    final pageContext = context;
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    String tempSelectedLanguageCode = languageProvider.currentLanguageCode;

    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final localizations = AppLocalizations.of(context);
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xffF44336).withOpacity(0.08),
                          const Color(0xffff5722).withOpacity(0.03),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                localizations?.selectLanguage ??
                                    'Select Language',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff212427),
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('Choose your preferred language'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(top: 16),
                        itemCount: languageProvider.supportedLanguages.length,
                        itemBuilder: (context, index) {
                          final language =
                              languageProvider.supportedLanguages[index];
                          final isSelected =
                              tempSelectedLanguageCode == language['code'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    tempSelectedLanguageCode =
                                        language['code']!;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffF44336)
                                          : Colors.grey[200]!,
                                      width: isSelected ? 1.0 : 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              language['name']!,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xff212427),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              language['nativeName']!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xff57636C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xffF44336)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xffF44336)
                                                : const Color(0xff57636C),
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xffF44336),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xffF44336),
                                  width: 1,
                                ),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              context.tr('Cancel'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF212427), // Black
                                  Color(0xFF57636C), // Grey
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                if (tempSelectedLanguageCode !=
                                    languageProvider.currentLanguageCode) {
                                  final shouldChange = await languageProvider
                                      .showLanguageChangeDialog(
                                    pageContext,
                                    tempSelectedLanguageCode,
                                  );
                                  if (shouldChange) {
                                    try {
                                      await languageProvider.changeLanguage(
                                        pageContext,
                                        tempSelectedLanguageCode,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(pageContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppLocalizations.of(pageContext)
                                                      ?.languageChanged ??
                                                  'Language changed successfully',
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        setState(() {
                                          _languageValue = languageProvider
                                              .currentLanguageName;
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(pageContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              pageContext.tr(
                                                'Error changing language: {error}',
                                                params: {'error': '$e'},
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                              child: Text(
                                localizations?.confirm ?? 'Confirm',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVisitorApprovalTime(BuildContext context) {
    int currentValue = context.read<VisitorApprovalTimeProvider>().approvalTime;
    int tempSelectedValue = currentValue; // Track temporary selection

    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced drag handle
                  const SizedBox(height: 12),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Enhanced header with gradient background
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xffF44336).withOpacity(0.08),
                          const Color(0xffff5722).withOpacity(0.03),
                        ],
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        // Compact icon section
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.timer_rounded,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Simple label section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('Select Approval Time'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff212427),
                                      fontSize: 20,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr(
                                  'Choose visitor approval duration',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xff57636C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(top: 16),
                        itemCount: _visitorApprovalTimeItems.length,
                        itemBuilder: (context, index) {
                          final item = _visitorApprovalTimeItems[index];
                          final isSelected =
                              tempSelectedValue == int.parse(item.value);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    tempSelectedValue = int.parse(item.value);
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffF44336)
                                          : Colors.grey[200]!,
                                      width: isSelected ? 1.0 : 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Time icon with background
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF44336)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.schedule,
                                          color: Color(0xffF44336),
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Time information
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr(item.label),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xff212427),
                                                    fontSize: 18,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              context.tr(
                                                'Approval timeout duration',
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xff57636C),
                                                    fontSize: 14,
                                                    height: 1.3,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Selection indicator - Checkbox
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xffF44336)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xffF44336)
                                                : const Color(0xff57636C),
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Confirm Button Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xffF44336),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xffF44336),
                                  width: 1,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              context.tr('Cancel'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff212427), Color(0xff57636C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                context
                                    .read<VisitorApprovalTimeProvider>()
                                    .setApprovalTime(tempSelectedValue);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xff4CAF50),
                                            Color(0xff45A049),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xff4CAF50)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.timer_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  context.tr('Success!'),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  context.tr(
                                                    'Approval time updated successfully',
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: Text(
                                context.tr('Confirm'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDataStorage(BuildContext context) async {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.red.shade50.withOpacity(0.3),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade300,
                          Colors.red.shade400,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storage_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            context.tr('Select Data Storage'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shrinkWrap: true,
                          itemCount: _dataStorageItems.length,
                          itemBuilder: (context, index) {
                            final item = _dataStorageItems[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _dataStorageValue == item.value
                                      ? Colors.red.shade300
                                      : Colors.grey.shade300,
                                  width:
                                      _dataStorageValue == item.value ? 2 : 1,
                                ),
                              ),
                              child: RadioListTile<String>(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                fillColor: WidgetStateProperty.all(
                                    Colors.red.shade400),
                                title: Text(
                                  context.tr(item.label),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight:
                                            _dataStorageValue == item.value
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                        color: _dataStorageValue == item.value
                                            ? Colors.red.shade400
                                            : Colors.grey.shade700,
                                      ),
                                ),
                                value: item.value,
                                groupValue: _dataStorageValue,
                                onChanged: (value) {
                                  setState(() {
                                    _dataStorageValue = value!;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.red.shade400,
                                Colors.red.shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _dataStorageValue = _dataStorageValue;
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              context.tr('Confirm'),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50.0),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? role;

  Future<void> _initializeRole() async {
    role = await GateStorage().getRole();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return MyScrollView(
      backButtonPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => GateDashboardView(),
          ),
          (route) => false,
        );
      },
      pageTitle: AppLocalizations.of(context)!.settings,
      pageBody: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16,
          vertical: isTablet ? 16 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnhancedSectionHeader(
              context: context,
              isTablet: isTablet,
              title: AppLocalizations.of(context)!.gateSettings,
              icon: Icons.settings_rounded,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            // if (role == "admin" || role == "master")
            PrimarySettingsTile(
              icon: Ionicons.people_outline,
              title: context.tr('Staff'),
              subtitle: context.tr('View your society staff'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StaffScreen(),
                  ),
                );
              },
            ),
            // Gate Settings (for Admin and Master only)
            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Ionicons.grid_outline,
                title: AppLocalizations.of(context)!.gateSettings,
                subtitle: AppLocalizations.of(context)!
                    .currentPreference(selectedGateName ?? "Not Selected Gate"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GateSelectionView(),
                    ),
                  );
                },
              ),
            if (role == "admin" || role == "master")
              PrimarySettingsTile(
                icon: Icons.settings_accessibility,
                title: AppLocalizations.of(context)!.visitorSettings,
                subtitle: context.tr('Mark mandatory fields for visitors'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GateSettingView(),
                    ),
                  );
                },
              ),

            // if (role == "admin" || role == "master")
            PrimarySettingsTile(
              icon: Icons.settings_accessibility,
              title: AppLocalizations.of(context)!.visitorSettings,
              subtitle: context.tr('Mark mandatory fields for visitors'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorSettingsView(),
                  ),
                );
              },
            ),

            PrimarySettingsTile(
              icon: Ionicons.time_outline,
              title: AppLocalizations.of(context)!.visitorApprovalTime,
              subtitle: AppLocalizations.of(context)!.currentPreference(
                '${context.watch<VisitorApprovalTimeProvider>().approvalTime} ${context.tr('seconds')}',
              ),
              onTap: () {
                _showVisitorApprovalTime(context);
              },
            ),

            SizedBox(height: isTablet ? 32 : 24),
            _buildEnhancedSectionHeader(
              context: context,
              isTablet: isTablet,
              title: AppLocalizations.of(context)!.applicationSettings,
              icon: Icons.apps_rounded,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            // Data Observability (for Admin, Master, and Gatekeeper)
            if (kDebugMode)
              if (role == "admin" || role == "master" || role == "gatekeeper")
                PrimarySettingsTile(
                  icon: Ionicons.pulse_outline,
                  title: context.tr('Data Observability'),
                  subtitle: context.tr(
                    'Monitor system health, search & notifications',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DataObservabilitySettingsScreen(),
                      ),
                    );
                  },
                ),
            // Camera Settings (for all roles)
            PrimarySettingsTile(
              icon: Ionicons.camera_outline,
              title: context.tr('Camera Settings'),
              subtitle: AppLocalizations.of(context)!.currentPreference(
                  context.watch<CameraSettingsProvider>().selectedCameraValue ??
                      "Not Selected Camera"),
              onTap: () {
                _showCameraSettings(context);
              },
            ),
            // Language settings available for all users
            PrimarySettingsTile(
              icon: Ionicons.language_outline,
              title: AppLocalizations.of(context)!.language,
              subtitle: AppLocalizations.of(context)!.currentPreference(
                  context.watch<LanguageProvider>().currentLanguageName),
              onTap: () {
                _showLanguageSettings(context);
              },
            ),
            // Express Entry (enable from settings)
            PrimarySettingsTile(
              icon: Ionicons.person_outline,
              title: context.tr('Express Entry'),
              subtitle: context.tr('Open express check-in options'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SelfHomeView(),
                  ),
                );
              },
            ),
            // Logout (for all roles)
            PrimarySettingsTile(
              icon: Ionicons.log_out_outline,
              title: context.tr('Logout'),
              subtitle: context.tr('Logout from the app'),
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    final isTablet = MediaQuery.of(context).size.width > 768;
                    final screenSize = MediaQuery.of(context).size;

                    return Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Container(
                        width: isTablet ? 500 : double.infinity,
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 500 : screenSize.width * 0.9,
                          maxHeight: screenSize.height * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Enhanced Header
                            Container(
                              padding: EdgeInsets.all(isTablet ? 28 : 24),
                              decoration: const BoxDecoration(
                                color: Color(0xffFFEBEE),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  topRight: Radius.circular(24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isTablet ? 14 : 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: Icon(
                                      Icons.logout_rounded,
                                      color: const Color(0xffF44336),
                                      size: isTablet ? 36 : 32,
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 20 : 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n?.confirmLogout ??
                                              'Confirm Logout',
                                          style: TextStyle(
                                            fontSize: isTablet ? 24 : 20,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xff212427),
                                          ),
                                        ),
                                        SizedBox(height: isTablet ? 6 : 4),
                                        Text(
                                          context.l10n
                                                  ?.securityConfirmationRequired ??
                                              'Security confirmation required',
                                          style: TextStyle(
                                            fontSize: isTablet ? 14 : 13,
                                            color: const Color(0xff57636C),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Enhanced content section
                            Padding(
                              padding: EdgeInsets.all(isTablet ? 28 : 24),
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n?.logoutMessage ??
                                              'Are you sure you want to logout?',
                                          style: TextStyle(
                                            fontSize: isTablet ? 18 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xff212427),
                                            height: 1.4,
                                          ),
                                        ),
                                        SizedBox(height: isTablet ? 12 : 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xffFF9800)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.info_outline,
                                                color: Color(0xffFF9800),
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                context.l10n
                                                        ?.logoutDescription ??
                                                    'You will need to sign in again to access your account.',
                                                style: TextStyle(
                                                  fontSize: isTablet ? 15 : 13,
                                                  color:
                                                      const Color(0xff57636C),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 28 : 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.symmetric(
                                              vertical: isTablet ? 16 : 14,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xff57636C),
                                              width: 1,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            context.l10n?.cancel ?? 'Cancel',
                                            style: TextStyle(
                                              color: const Color(0xff57636C),
                                              fontWeight: FontWeight.w600,
                                              fontSize: isTablet ? 16 : 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isTablet ? 16 : 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xffF44336),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: EdgeInsets.symmetric(
                                              vertical: isTablet ? 16 : 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () async {
                                            // Close dialog first
                                            Navigator.pop(context);
                                            // Then immediately logout and navigate
                                            await logout(context);
                                          },
                                          child: Text(
                                            context.tr('Logout'),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: isTablet ? 16 : 14,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            // Add bottom spacing for better scrolling
            SizedBox(height: isTablet ? 120 : 100),
          ],
        ),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    try {
      log("🚪 Settings Screen - Starting immediate logout process...");

      // Step 1: IMMEDIATELY clear all authentication tokens and data BEFORE navigation
      // This prevents any background authentication checks from detecting user as still logged in
      await _immediatelyNullifyAuthentication();

      // Step 2: Immediately navigate to login page to prevent getting stuck
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MyAppLogin()),
          (route) => false,
        );
        log("✅ Navigated to login page immediately after token clearing");
      }

      // Step 3: Perform complete cleanup in background (after navigation)
      try {
        await CentralizedLogoutService.performCompleteLogout(
          source: 'Settings Screen',
          showNotifications:
              false, // Don't show notifications since we've already navigated
        );
        log("✅ Background logout cleanup completed");
      } catch (cleanupError) {
        log("⚠️ Background cleanup had issues: $cleanupError");
        // Continue anyway since we've already cleared tokens and navigated to login
      }
    } catch (e, st) {
      log("❌ Settings Screen logout failed: $e\n$st");

      // Fallback: Ensure we still navigate to login even if there are errors
      if (context.mounted) {
        try {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MyAppLogin()),
            (route) => false,
          );
          log("✅ Fallback navigation to login completed");
        } catch (navError) {
          log("❌ Even fallback navigation failed: $navError");
        }
      }
    }
  }

  /// Immediately clear all authentication data to prevent background checks from detecting user as authenticated
  Future<void> _immediatelyNullifyAuthentication() async {
    try {
      log("🔧 Immediately nullifying authentication state...");

      final gateStorage = GateStorage();
      final prefs = await SharedPreferences.getInstance();

      // Immediately clear all authentication tokens
      await gateStorage.clearTokens();

      // Clear critical authentication keys from SharedPreferences immediately
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('id_token');
      await prefs.remove('user_id');
      await prefs.remove('role');
      await prefs.remove('session_timestamp');

      // Clear secure storage tokens immediately
      const FlutterSecureStorage secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: 'access_token_secure');
      await secureStorage.delete(key: 'refresh_token_secure');
      await secureStorage.delete(key: 'id_token_secure');

      log("✅ Authentication state immediately nullified");
    } catch (e) {
      log("❌ Error nullifying authentication: $e");
      // Continue anyway to ensure navigation happens
    }
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  Future<void> getCameraValue() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cameraValue = prefs.getString('selected_camera');
    });
  }

  // Enhanced section header
  Widget _buildEnhancedSectionHeader({
    required BuildContext context,
    required bool isTablet,
    required String title,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade300.withOpacity(0.08),
            Colors.red.shade400.withOpacity(0.15),
            Colors.red.shade300.withOpacity(0.08),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.shade300.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade300,
                  Colors.red.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 14),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff212427),
                    fontSize: isTablet ? 22 : 20,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimarySettingsTile extends StatelessWidget {
  const PrimarySettingsTile({
    super.key,
    this.icon,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.subtitleWidget,
    this.trailing,
    this.titleStyle,
    this.subtitleStyle,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? leadingIcon;
  final Widget? subtitleWidget;
  final TextStyle? subtitleStyle;
  final TextStyle? titleStyle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 14 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: leadingIcon ??
                        Icon(
                          icon,
                          size: isTablet ? 28 : 24,
                          color: Colors.red.shade400,
                        ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: titleStyle ??
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff212427),
                                  fontSize: isTablet ? 18 : 16,
                                  letterSpacing: 0.2,
                                ),
                      ),
                      if (subtitle != null || subtitleWidget != null) ...[
                        SizedBox(height: isTablet ? 6 : 4),
                        subtitleWidget ??
                            Text(
                              subtitle ?? '',
                              style: subtitleStyle ??
                                  Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey.shade600,
                                        fontSize: isTablet ? 15 : 14,
                                        height: 1.3,
                                      ),
                            ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: isTablet ? 12 : 8),
                  trailing!,
                ] else ...[
                  SizedBox(width: isTablet ? 12 : 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: isTablet ? 28 : 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MultiSelectItem<T> {
  final String label;
  final T value;

  MultiSelectItem(this.label, this.value);
}

List<MultiSelectItem<String>> _dataStorageItems = [
  MultiSelectItem<String>('1 month', '1'),
  MultiSelectItem<String>('2 months', '2'),
  MultiSelectItem<String>('3 months', '3'),
  MultiSelectItem<String>('4 months', '4'),
  MultiSelectItem<String>('5 months', '5'),
  MultiSelectItem<String>('6 months', '6'),
];

List<MultiSelectItem<String>> _cameraItems = [
  MultiSelectItem<String>('Front Camera', 'front'),
  MultiSelectItem<String>('Back Camera', 'back'),
];
List<MultiSelectItem<String>> _languageItems = [
  MultiSelectItem<String>('English', 'English'),
  MultiSelectItem<String>('Marathi', 'Marathi'),
  MultiSelectItem<String>('Hindi', 'Hindi'),
];
List<MultiSelectItem<String>> _visitorApprovalTimeItems = [
  MultiSelectItem<String>('visitorApprovalTimeOption20', '20'),
  MultiSelectItem<String>('visitorApprovalTimeOption40', '40'),
  MultiSelectItem<String>('visitorApprovalTimeOption60', '60'),
  MultiSelectItem<String>('visitorApprovalTimeOption80', '80'),
  MultiSelectItem<String>('visitorApprovalTimeOption100', '100'),
  MultiSelectItem<String>('visitorApprovalTimeOption120', '120'),
];
