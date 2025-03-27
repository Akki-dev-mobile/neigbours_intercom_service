// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/ui/unit_selection_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:path/path.dart' as path;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/provider/purposeProvider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/entity/purpose_mapper.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toggle_switch/toggle_switch.dart';

import '../../../visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';

class IdInputView extends StatefulWidget {
  const IdInputView({Key? key}) : super(key: key);

  @override
  State<IdInputView> createState() => _IdInputViewState();
}

late FocusNode _focusNode;

int _currentIndex = 0;
List<String> _labels = ['Mobile', 'Pass Code'];
String? selectedPassAlpha = 'A';
String selectedCountryCode = 'IN';
final isoCode = selectedCountryCode;
Visitor? searchedVisitor;

List<String> listPassAlpha = [
  'G',
  'S',
  'A',
];

class _IdInputViewState extends State<IdInputView> {
  final mobileControllerFormKey = GlobalKey<FormState>();
  final passcodeControllerFormKey = GlobalKey<FormState>();
  TextEditingController mobileController = TextEditingController();
  TextEditingController passcodeController = TextEditingController();
  bool isLoading = false;

  void startLoading() {
    setState(() {
      isLoading = true;
    });
  }

  void stopLoading() {
    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    // Request focus after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
      mobileController.clear(); // Clear after the build phase
    });

    loadPurposes();
  }

  final gateDashboardBloc = GatekeeperDashboardBloc(
      VisitorUsecase(
        VisitorRepoImpl(
          RemoteDataSource(),
        ),
      ),
      VisitorLogUsecase(
        VisitorLogRepositoryImpl(
          RemoteDataSource(),
        ),
      ));
  final provider = PurposeProvider();
  RemoteDataSource remoteDataSource = new RemoteDataSource();

  @override
  void dispose() {
    _currentIndex = 0;
    // mobileController.dispose();
    mobileController.clear();
    super.dispose();

    mobileController.text = '';
  }

  List<PurposeCategory1> globalSelectedPurposes = [];

  Future<void> loadPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPurposes = prefs.getString('selected_purposes');
      if (savedPurposes != null) {
        final decoded = jsonDecode(savedPurposes) as List;
        globalSelectedPurposes =
            decoded.map((e) => PurposeCategory1.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Failed to load purposes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocConsumer<GatekeeperDashboardBloc, GatekeeperDashboardState>(
          bloc: gateDashboardBloc,
          listenWhen: (previous, current) =>
              current is GatekeeperDashboardActionState,
          buildWhen: (previous, current) =>
              current is! GatekeeperDashboardActionState,
          listener: (context, state) async {
            if (state is OpenPurposeDialogState) {
              if (globalSelectedPurposes.length == 1) {
                final singlePurpose = globalSelectedPurposes.first;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorsInEntry(
                      searchedVisitor: searchedVisitor,
                      selectedValue: singlePurpose,
                      mobile: mobileController.text,
                    ),
                  ),
                );
                return; // Exit early
              }
              showModalBottomSheet(
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                context: context,
                builder: (context) => ImageGridBottomSheet(
                  purposeCategories: state.purposeCategories!.toList(),
                  gatekeeperDashboardBloc: gateDashboardBloc,
                  mobileNumber:
                      mobileController.text, // Pass mobile number here
                ),
              );
            }

            switch (state.runtimeType) {
              case GatekeeperDashboardErrorState:
                final errorState = state as GatekeeperDashboardErrorState;
                myFluttertoast(
                  msg: errorState.message!,
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
                break;

              case SaveSearchedVisitorState:
                final saveVisitorState = state as SaveSearchedVisitorState;
                searchedVisitor = saveVisitorState.visitor;
                break;

              case InputPutViewNextClickedState:
                // Example: Set loading state here if needed
                break;

              case NavigateToVisitorDetailsState:
                final navigateToVisitorDetailsState =
                    state as NavigateToVisitorDetailsState;
                // mobileController.text = '';

                // Retrieve and decode the saved purpose
                final prefs = await SharedPreferences.getInstance();
                final jsonString = prefs.getString("dialoguePurpose");
                PurposeCategory1? selectedPurpose;
                if (jsonString != null) {
                  final json = jsonDecode(jsonString);
                  selectedPurpose = PurposeCategory1.fromJson(json);
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorsInEntry(
                      searchedVisitor: navigateToVisitorDetailsState.visitor,
                      mobile: mobileController.text,
                      selectedValue: selectedPurpose,
                    ),
                  ),
                );
                break;
            }
          },
          builder: (context, state) {
            return Form(
              key: mobileControllerFormKey,
              child: MyScrollView(
                pageTitle: _currentIndex == 0
                    ? 'Enter Mobile Number'
                    : 'Enter Passcode',
                pageBody: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToggleSwitch(
                      totalSwitches: 2,
                      labels: _labels,
                      minWidth: 400.0,
                      cornerRadius: 0.0,
                      // Rectangle shape
                      activeBgColors: [
                        [Colors.black],
                        [Colors.black],
                      ],
                      activeFgColor: Colors.white,
                      inactiveBgColor: Colors.white,
                      inactiveFgColor: Colors.black,
                      borderWidth: 2,
                      borderColor: [Colors.black],
                      fontSize: 16.0,
                      animate: true,
                      curve: Curves.easeInOut,
                      initialLabelIndex: _currentIndex,
                      onToggle: (index) {
                        if (index != null) {
                          setState(() {
                            _currentIndex = index;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 20),
                    _currentIndex == 0
                        ? CustomForm.textField(
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Mobile number is required';
                              } else if (value.length != 10) {
                                return 'Please enter a 10-digit number';
                              } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                                return 'No spaces or special characters allowed';
                              }
                              return null;
                            },
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Visitor Mobile Number",
                            hintText: '0123456789',
                            prefixIcon: CountryCodePicker(
                              initialSelection: 'IN',
                              favorite: ['IN'],
                              showFlagMain: true,
                              showFlagDialog: true,
                              boxDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.background,
                              ),
                              barrierColor: Theme.of(context)
                                  .colorScheme
                                  .background
                                  .withOpacity(0.5),
                              closeIcon: Icon(
                                Icons.close,
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                              searchDecoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                  ),
                                ),
                              ),
                              textStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                                fontSize: 18,
                              ),
                              dialogTextStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                              onChanged: (CountryCode countryCode) {
                                setState(() {
                                  selectedCountryCode = countryCode.code!;
                                });
                              },
                            ),
                            textController: mobileController,
                            keyboardType: TextInputType.number,
                            length: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.length == 10) {
                                gateDashboardBloc.add(
                                  GDOnMobileNumberEnteredEvent(
                                      mobileController.text),
                                );
                              }
                            },
                          )
                        : Column(
                            children: [
                              Form(
                                key: passcodeControllerFormKey,
                                child: CustomForm.textField(
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Passcode is required';
                                    } else if (value.length != 6) {
                                      return 'Please enter a 6-digit passcode';
                                    }
                                    return null;
                                  },
                                  titleColor: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                  hintColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  "Visitor Passcode",
                                  hintText: '123456',
                                  textController: passcodeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  length: 6,
                                  keyboardType: TextInputType.number,
                                  // prefixIcon: Padding(
                                  //   padding:
                                  //       EdgeInsets.only(left: 10, right: 20),
                                  //   child: CircleAvatar(
                                  //     backgroundColor: Color(0xffFFEBE6),
                                  //     child: Text(
                                  //       selectedPassAlpha ?? 'A',
                                  //       style: TextStyle(
                                  //         color: Colors.black,
                                  //         fontWeight: FontWeight.bold,
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      if (passcodeControllerFormKey
                                          .currentState!
                                          .validate()) {
                                        // Show modal bottom sheet or handle passcode submission
                                      }
                                    },
                                    icon: Icon(
                                      Symbols.done_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
                floatingActionButton: CustomLargeBtn(
                    text: 'Next',
                    onPressed: () async {
                      _focusNode.unfocus();

                      if (_currentIndex == 0) {
                        // Mobile number validation & processing
                        if (mobileControllerFormKey.currentState?.validate() ??
                            false) {
                          gateDashboardBloc.add(InputPutViewNextClickedEvent());
                        }
                      } else {
                        // Passcode verification process
                        if (passcodeControllerFormKey.currentState
                                ?.validate() ??
                            false) {
                          _handlePasscodeVerification();
                        }
                      }
                    }
                    // _focusNode.unfocus();
                    //
                    // if (_currentIndex == 0) {
                    //   if (mobileControllerFormKey.currentState?.validate() ??
                    //       false) {
                    //     startLoading(); // Show loader
                    //     await remoteDataSource
                    //         .searchVisitor(mobileController.text);
                    //
                    //     final prefs = await SharedPreferences.getInstance();
                    //     bool isStaff = prefs.getBool('isStaff') ?? false;
                    //     print("Staff Check: $isStaff");
                    //
                    //     String visitorName =
                    //         prefs.getString('visitorName') ?? "";
                    //     String visitorMobile =
                    //         prefs.getString('visitorMobile') ?? "";
                    //     String visitorImage =
                    //         prefs.getString('visitorImage') ?? "";
                    //     String? staffCategory =
                    //         prefs.getString('staffCategory');
                    //     await remoteDataSource.createVisitor(Visitor(
                    //       visitor_image: visitorImage,
                    //       name: visitorName,
                    //       mobile: visitorMobile,
                    //     ));
                    //     stopLoading(); // Hide loader
                    //
                    //     if (isStaff) {
                    //       log("✅ Auto-selecting STAFF");
                    //
                    //       // Show indication before navigation
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         SnackBar(
                    //           content: Text(
                    //               "Number entered belongs to STAFF ($staffCategory)"),
                    //           duration: Duration(seconds: 2),
                    //           // Show for 2 seconds
                    //           backgroundColor: Colors.green,
                    //         ),
                    //       );
                    //
                    //       // ✅ Wait for a short duration before navigating
                    //       await Future.delayed(Duration(seconds: 2));
                    //
                    //       PurposeCategory1 staffPurpose = PurposeCategory1(
                    //         categoryName: staffCategory ?? "STAFF",
                    //         image: "staff_image_url",
                    //         categoryId: 5,
                    //       );
                    //
                    //       Navigator.pushReplacement(
                    //         context,
                    //         MaterialPageRoute(
                    //           builder: (context) => UnitSelectionView(
                    //             Visitor(
                    //               id: int.parse(
                    //                   prefs.getString('visitorId') ?? "0"),
                    //               name: visitorName,
                    //               mobile: visitorMobile,
                    //               visitor_image: visitorImage,
                    //             ),
                    //             purposeCategory: staffPurpose,
                    //             guestname: visitorName,
                    //             mobileNumber: visitorMobile,
                    //             visitor: Visitor(
                    //               id: int.parse(
                    //                   prefs.getString('visitorId') ?? "0"),
                    //               name: visitorName,
                    //               mobile: visitorMobile,
                    //               visitor_image: visitorImage,
                    //             ),
                    //           ),
                    //         ),
                    //       );
                    //       prefs.remove("isStaff");
                    //     } else {
                    //       // 🚫 If not staff, proceed with the normal visitor flow
                    //       myFluttertoast(
                    //           msg: "Number entered is a normal visitor");
                    //       gateDashboardBloc
                    //           .add(InputPutViewNextClickedEvent());
                    //     }
                    //   }
                    // } else {
                    //   if (passcodeControllerFormKey.currentState
                    //           ?.validate() ??
                    //       false) {
                    //     _handlePasscodeVerification();
                    //   }

                    ),
              ),
            );
          },
        ),
        if (isLoading) const LoaderView(), // LoaderView overlay
      ],
    );
  }

  File? _imageFile;
  var visitorData;

  /// ✅ Handles Passcode Verification & Captures Image if Verified
  Future<void> _handlePasscodeVerification() async {
    startLoading(); // Show loading indicator

    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');

      // 🔍 Verify Passcode
      final result = await remoteDataSource.verifyPasscode(
        companyId: companyId ?? "",
        passcode: passcodeController.text,
      );

      stopLoading(); // Hide loading indicator
      print("✅ Verification Result: $result");

      if (result['success'] == true && result['data'] != null) {
        visitorData = result['data'][0]; // Get first visitor entry
        print("visitorData$visitorData");

        final String mobileNumber = visitorData['mobile'];
        final String name = visitorData['name'];

        final int id = visitorData['visitor_id'];

        myFluttertoast(
          msg: "✅ Passcode verified successfully!",
          backgroundColor: Colors.green,
        );

        // print("📞 Extracted Mobile Number: $mobileNumber $id");

        // ✅ Check & Request Camera Permission, then Capture Image
        await _requestCameraPermissionAndCapture(mobileNumber, id.toString());
      } else {
        myFluttertoast(
          msg: "❌ Invalid passcode. Try again.",
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      stopLoading();
      // myFluttertoast(
      //   msg: "❌ Error verifying passcode: $e",
      //   backgroundColor: Colors.red,
      // );
    }
  }

  /// ✅ Requests Camera Permission & Captures Image
  Future<void> _requestCameraPermissionAndCapture(
      String mobileNumber, String id) async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isDenied || status.isRestricted) {
      // Request permission
      status = await Permission.camera.request();

      if (!status.isGranted) {
        print("❌ Camera permission denied!");
        myFluttertoast(
          msg: "Camera permission required to capture an image.",
          backgroundColor: Colors.orange,
        );
        return;
      }
    }

    // ✅ Capture Image if Permission is Granted
    await _captureImageFromCamera(mobileNumber, id);
  }

  /// ✅ Captures Image from Camera & Uploads it
  Future<void> _captureImageFromCamera(String mobileNumber, String id) async {
    final picker = ImagePicker();
    XFile? image;

    try {
      // 📷 Capture image from camera
      image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        print("❌ No image captured");
        return;
      }

      setState(() {
        _imageFile = File(image!.path);
      });

      print("📷 Image captured: ${_imageFile!.path}");

      // ✅ Upload the captured image
      await _uploadCapturedImage(mobileNumber, id);
    } catch (e) {
      log('❌ Error capturing image from camera: $e');
    }
  }

  Future<void> _uploadCapturedImage(String mobileNumber, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('company_id');

      if (_imageFile == null) {
        print("❌ No image to upload.");
        return;
      }

      // ✅ Compress Image
      File? compressedImage = await _compressImage(_imageFile!);
      if (compressedImage == null) {
        print("❌ Compression failed, using original file.");
        compressedImage = _imageFile!;
      }

      print("📷 Final Image Size: ${compressedImage.lengthSync()} bytes");

      // ✅ Upload Image to Server
      final response = await remoteDataSource.uploadFile(
        compressedImage,
        mobileNumber,
        int.parse(companyId ?? "0"),
      );

      print("✅ Image uploaded successfully: $response");

      if (response != null) {
        await prefs.setString('uploaded_image_url', response);
        print("🔄 Image URL saved: $response");

        // ✅ Update Visitor Entry with Uploaded Image URL
        await _updateVisitorEntry(mobileNumber, response, id);
        await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => RequestPermissionPage2(
                    visitorLog: VisitorLog(
                      visitor_purpose_Category_name: visitorData['category'],
                      visitor_building_assignment: [
                        BuildingAssignment(
                          unit_id: [visitorData['unit_id']],
                          visitor_id: visitorData['visitor_id'],
                        )
                      ],
                    ),
                    visitor: Visitor(
                        name: visitorData['name'],
                        mobile: visitorData['mobile'],
                        visitor_image: response))));
      }
    } catch (e) {
      print("❌ Error uploading image: $e");
    }
  }

  /// ✅ Compress Image Before Uploading
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
          dir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg");

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Adjust quality (higher = better, but larger file)
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print("❌ Error compressing image: $e");
      return null;
    }
  }

  /// ✅ PATCH Request to Update Visitor Entry
  Future<void> _updateVisitorEntry(
      String mobileNumber, String imageUrl, String id) async {
    try {
      int id1 = int.parse(id);
      final dio = Dio();
      final String apiUrl =
          "https://stggateapi.cubeone.in/api/visitor/entry/$id1";

      final data = {
        "visitor_image": imageUrl,
      };

      final response = await dio.patch(
        apiUrl,
        options: Options(headers: {"Content-Type": "application/json"}),
        data: data,
      );

      if (response.statusCode == 200) {
        print("✅ Visitor entry updated successfully: ${response.data}");
      } else {
        print("❌ Failed to update visitor entry: ${response.statusMessage}");
      }
    } catch (e) {
      print("❌ Error updating visitor entry: $e");
    }

    // ✅ Navigate to Dashboard after successful update
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GateDashboardView(),
      ),
    );
  }
}

class ImageGridBottomSheet extends StatefulWidget {
  final List<PurposeCategory1> purposeCategories;
  final GatekeeperDashboardBloc gatekeeperDashboardBloc;
  final String mobileNumber; // <-- Add this
  VisitorMapper? searchedVisitor;

  ImageGridBottomSheet({
    super.key,
    required this.purposeCategories,
    this.searchedVisitor,
    required this.gatekeeperDashboardBloc,
    required this.mobileNumber, // <-- Add this
  });

  @override
  _ImageGridBottomSheetState createState() => _ImageGridBottomSheetState();
}

class _ImageGridBottomSheetState extends State<ImageGridBottomSheet> {
  int? selectedImageIndex;

  @override
  void initState() {
    super.initState();
    _loadSelectedPurposesToGlobal();
  }

  List<PurposeCategory1> globalSelectedPurposes = [];

  Future<void> _loadSelectedPurposesToGlobal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_purposes');

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          globalSelectedPurposes =
              jsonList.map((json) => PurposeCategory1.fromJson(json)).toList();
        });
        print("Global selected purposes loaded: ${globalSelectedPurposes}");
      } else {
        print("No selected purposes found in SharedPreferences.");
      }
    } catch (e) {
      print("Failed to load selected purposes into global variable: $e");
    }
  }

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ListTile(
            title: Text(
              'Select Purpose of visit',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            trailing: const Icon(
              Ionicons.close_circle_outline,
              color: Colors.red,
              size: 28,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: globalSelectedPurposes.isEmpty
                ? GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                    itemCount: widget.purposeCategories
                        .where((purpose) => purpose.categoryName == "GUEST")
                        .length,
                    itemBuilder: (context, index) {
                      final guestPurposes = widget.purposeCategories
                          .where((purpose) => purpose.categoryName == "GUEST")
                          .toList();
                      final purpose = guestPurposes[index];

                      return GestureDetector(
                        onTap: () => selectImage(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 250,
                              width: 200,
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: selectedImageIndex == 4
                                    ? const Color(0x10C08261)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selectedImageIndex == 4
                                      ? const Color(0xffC08261)
                                      : Colors.grey,
                                  width: selectedImageIndex == 4 ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: CachedNetworkImage(
                                        maxHeightDiskCache: 90,
                                        maxWidthDiskCache: 90,
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                        imageUrl: purpose.image ?? "",
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        purpose.categoryName,
                                        style: TextStyle(
                                          color: selectedImageIndex == 4
                                              ? const Color(0xffC08261)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                          fontWeight: selectedImageIndex == 4
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedImageIndex == 4)
                              const Positioned(
                                right: 10,
                                top: 10,
                                child: Icon(
                                  size: 20,
                                  Ionicons.checkmark_circle_outline,
                                  color: Color(0xffC08261),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                    itemCount: globalSelectedPurposes.length,
                    itemBuilder: (context, index) {
                      final purpose = globalSelectedPurposes[index];
                      return GestureDetector(
                        onTap: () => selectImage(index),
                        child: Stack(
                          children: [
                            Container(
                              height: 250,
                              width: 200,
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: selectedImageIndex == index
                                    ? const Color(0x10C08261)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selectedImageIndex == index
                                      ? const Color(0xffC08261)
                                      : Colors.grey,
                                  width: selectedImageIndex == index ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: CachedNetworkImage(
                                        maxHeightDiskCache: 90,
                                        maxWidthDiskCache: 90,
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                        imageUrl: purpose.image ?? "",
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        purpose.categoryName,
                                        style: TextStyle(
                                          color: selectedImageIndex == index
                                              ? const Color(0xffC08261)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                          fontWeight:
                                              selectedImageIndex == index
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedImageIndex == index)
                              const Positioned(
                                right: 10,
                                top: 10,
                                child: Icon(
                                  size: 20,
                                  Ionicons.checkmark_circle_outline,
                                  color: Color(0xffC08261),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomLargeBtn(
              text: 'Next',
              onPressed: () async {
                FocusScope.of(context).unfocus();
                if (selectedImageIndex == null) {
                  myFluttertoast(
                      msg: "please select purpose",
                      backgroundColor: Colors.red);
                  return;
                }

                if (selectedImageIndex != -1) {
                  final selectedValue = globalSelectedPurposes.isEmpty
                      ? widget.purposeCategories[selectedImageIndex!]
                      : globalSelectedPurposes[selectedImageIndex!];

                  Navigator.pop(
                    context,
                    selectedValue,
                  );

                  final dialogue = await SharedPreferences.getInstance();
                  await dialogue.setString(
                    "dialoguePurpose",
                    jsonEncode(selectedValue.toJson()),
                  );

                  widget.gatekeeperDashboardBloc.add(
                    PurposeNextButtonClickedEvent(
                      selectedValue,
                      searchedVisitor,
                      widget.mobileNumber,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
