import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:flutter_onegate/presentation/widgets/enhanced_toast.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'dart:convert';

class PasscodeEntryView extends StatefulWidget {
  final bool selfcheckinFlow;

  const PasscodeEntryView({super.key, this.selfcheckinFlow = false});

  @override
  State<PasscodeEntryView> createState() => _PasscodeEntryViewState();
}

class _PasscodeEntryViewState extends State<PasscodeEntryView> {
  final passcodeController = TextEditingController();
  final passcodeControllerFormKey = GlobalKey<FormState>();
  bool isLoading = false;
  final RemoteDataSource remoteDataSource = RemoteDataSource();

  List<String> listPassAlpha = ['G', 'S', 'A'];
  String selectedPassAlpha = 'A';

  @override
  void initState() {
    super.initState();
    _trackExpressEntryRoute();
  }

  // Track that user is in express entry flow
  Future<void> _trackExpressEntryRoute() async {
    if (widget.selfcheckinFlow) {
      await RouteTracker.saveCurrentRoute(
        'PasscodeEntryView',
        isExpressEntry: true,
      );
    }
  }

  void startLoading() => setState(() => isLoading = true);

  void stopLoading() => setState(() => isLoading = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).enterPasscode),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xff212427),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Enhanced Passcode Field Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header Section with Icon and Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: AppLocalizations.of(context)
                                          .visitorPasscode,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff212427),
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' *',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xffF44336),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)
                                    .enterSixDigitPasscode,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xff57636C),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Input Field Section
                  Container(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: Form(
                      key: passcodeControllerFormKey,
                      child: TextFormField(
                        controller: passcodeController,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.characters,
                        cursorColor: const Color(0xffF44336),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff212427),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)
                                .passcodeRequired;
                          } else if (value.length != 6) {
                            return AppLocalizations.of(context)
                                .enterSixDigitValidation;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: '123456',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xff57636C),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF44336).withOpacity(0.02),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xffF44336),
                              width: 2,
                            ),
                          ),
                          counterText: '',
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            child: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              radius: 20,
                              child: IconButton(
                                onPressed: () {
                                  if (passcodeControllerFormKey.currentState!
                                      .validate()) {
                                    // Optionally handle immediate validation
                                  }
                                },
                                icon: const Icon(
                                  Symbols.done_rounded,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Enhanced Next Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              width: MediaQuery.of(context).size.width * 0.85,
              height: 60,
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all<Color>(Colors.transparent),
                  elevation: WidgetStateProperty.all<double>(0),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (passcodeControllerFormKey.currentState
                                ?.validate() ??
                            false) {
                          startLoading();

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final companyId = prefs.getString('company_id');

                            final result =
                                await remoteDataSource.verifyPasscode(
                              companyId: companyId ?? "",
                              passcode: passcodeController.text,
                            );

                            stopLoading();

                            if (result['success'] == true &&
                                result['data'] != null) {
                              final visitorData = result['data'][0];

                              // Parse unit details from the response (same as QR flow)
                              List<BuildingAssignment> parsedUnitDetails = [];
                              try {
                                final dynamic unitDetailsValue =
                                    visitorData['unit_details'];
                                if (unitDetailsValue is String) {
                                  final String cleanedJsonString =
                                      unitDetailsValue
                                          .replaceAll(r'\"', '"')
                                          .replaceAll('"[', '[')
                                          .replaceAll(']"', ']');
                                  final List<dynamic> decodedUnitDetails =
                                      jsonDecode(cleanedJsonString);
                                  parsedUnitDetails = decodedUnitDetails
                                      .map<BuildingAssignment>((unitJson) {
                                    return BuildingAssignment(
                                      unit_id: [
                                        unitJson["building_unit"]?.toString() ??
                                            ''
                                      ],
                                      company_id: visitorData['company_id'],
                                    );
                                  }).toList();
                                }
                              } catch (e) {
                                print("❌ Error decoding unit details: $e");
                              }

                              // Create Visitor object from passcode verification data
                              Visitor visitor = Visitor(
                                id: visitorData['visitor_id'],
                                name: visitorData['name'],
                                mobile: visitorData['mobile'],
                                visitor_image: visitorData['visitor_image'],
                              );

                              // Extract visitor_count from API response, checking both visitor_count and guest_count fields
                              final int visitorCount = visitorData['visitor_count'] ?? 
                                                       visitorData['guest_count'] ?? 
                                                       1;

                              // Create VisitorLog object with unit details
                              VisitorLog visitorLog = VisitorLog(
                                visitor: visitor,
                                visitor_coming_from: visitorData['coming_from'],
                                visitor_purpose_Category_name:
                                    visitorData['category'] ?? "Guest",
                                visitor_purpose_category_id: 1,
                                visitor_count: visitorCount,
                                company_id: visitorData['company_id'],
                                initiated_from:
                                    "passcode_entry", // Mark as passcode entry
                                visitor_building_assignment: parsedUnitDetails,
                              );

                              // Show enhanced success toast
                              showEnhancedToast(
                                context,
                                title: "Passcode Verified",
                                message:
                                    "Welcome ${visitor.name}! Proceeding to purpose entry.",
                                backgroundColor: Colors.green,
                                icon: Icons.verified_user,
                              );

                              // Store flag indicating entry came from passcode
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                  'entry_method', 'passcode_entry');

                              // Short delay to show success toast
                              await Future.delayed(
                                  const Duration(milliseconds: 1500));

                              // Determine the correct purpose category from API response
                              final String categoryFromApi =
                                  visitorData['category']?.toString() ??
                                      "Guest";

                              // Fetch the complete purpose data including subcategories
                              final PurposeCategory1? completePurpose =
                                  await _getCompletePurposeData(
                                      categoryFromApi);

                              // Navigate to VisitorsInEntry with autopopulated data based on actual entry type
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VisitorsInEntry(
                                    selfcheckinFlow: widget.selfcheckinFlow,
                                    comingfrom: visitorData['coming_from'],
                                    searchedVisitor: visitor,
                                    selectedValue: completePurpose ??
                                        PurposeCategory1(
                                            categoryId: 1,
                                            categoryName: "Guest"),
                                    mobile: visitor.mobile ?? "",
                                    guestname: visitor.name ?? "",
                                    isFromQRScan:
                                        true, // Set to true so it uses visitorLog data like QR flow
                                    isGatekeeperQRPasscodeEntry:
                                        false, // This is self-entry flow
                                    visitorLog: visitorLog,
                                  ),
                                ),
                              );
                            } else {
                              myFluttertoast(
                                msg: AppLocalizations.of(context)
                                    .invalidPasscodeTryAgain,
                                backgroundColor: Colors.red,
                              );
                            }
                          } catch (e) {
                            stopLoading();
                            showEnhancedToast(
                              context,
                              title: "Invalid Passcode",
                              message: AppLocalizations.of(context)
                                  .errorVerifyingPasscode,
                              backgroundColor: const Color(0xFFD32F2F),
                              icon: Icons.lock_outline,
                            );
                          }
                        }
                      },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff212427), Color(0xff57636C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            AppLocalizations.of(context).next,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              wordSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to get category ID from category name
  int _getCategoryIdFromName(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'STAFF':
        return 2;
      case 'DELIVERY':
        return 3;
      case 'MEMBER STAFF':
        return 4;
      case 'VENDOR':
        return 5;
      case 'CABS':
        return 6;
      case 'GUEST':
      default:
        return 1;
    }
  }

  /// Fetch complete purpose data including subcategories from API
  Future<PurposeCategory1?> _getCompletePurposeData(String categoryName) async {
    try {
      final purposes = await remoteDataSource.fetchPurpose();
      if (purposes != null) {
        // Find the purpose that matches the category name
        for (final purpose in purposes) {
          if (purpose.categoryName.toUpperCase() ==
              categoryName.toUpperCase()) {
            return purpose;
          }
        }
      }
    } catch (e) {
      print("❌ Error fetching complete purpose data: $e");
    }
    return null;
  }
}
