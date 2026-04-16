import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/building_assignment.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/entity/purpose_mapper.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_screens/widgets/request_2.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/face_liveness_camera_screen.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';

import '../../units_selection/ui/unit_selection_view.dart';
import '../bloc/visitor_in_entry_bloc.dart';

class VisitorsInEntry extends StatefulWidget {
  var comingfrom;
  final PurposeCategory1? selectedValue;
  final Visitor? searchedVisitor;
  final bool selfcheckinFlow;
  final String mobile;
  final String? guestname;
  final bool isFromQRScan;
  final bool isGatekeeperQRPasscodeEntry;
  final VisitorLog? visitorLog;

  VisitorsInEntry({
    Key? key,
    this.selectedValue,
    this.searchedVisitor,
    this.comingfrom,
    this.selfcheckinFlow = false,
    required this.mobile,
    this.guestname,
    this.isFromQRScan = false,
    this.isGatekeeperQRPasscodeEntry = false,
    this.visitorLog,
  }) : super(key: key);

  @override
  State<VisitorsInEntry> createState() => _VisitorsInEntryState();
}

class _VisitorsInEntryState extends State<VisitorsInEntry> {
  late final VisitorInEntryBloc _bloc;
  TextEditingController? _guestNameController;
  TextEditingController? _guestComingFromController;
  TextEditingController? _guestCountController;
  TextEditingController? _visitorNumberController;
  TextEditingController? _carNumberController;

  // Focus nodes for field highlighting
  FocusNode? _guestNameFocusNode;
  FocusNode? _guestComingFromFocusNode;
  FocusNode? _visitorNumberFocusNode;
  FocusNode? _carNumberFocusNode;

  int selectedCompanyIndex = -1;
  List<CameraDescription>? cachedCameras;
  bool _speechEnabled = false;

  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isSubmitting = false;
  int _guestCount = 1;
  bool? _visitorCardNumber = false;
  bool? _visitorAddress = false;
  List<PurposeCategory1> _globalSelectedPurposes = [];
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  String? selectedSubCategoryId;

  // Track that user is in express entry flow
  Future<void> _trackExpressEntryRoute() async {
    if (widget.selfcheckinFlow) {
      await RouteTracker.saveCurrentRoute(
        'VisitorsInEntry',
        isExpressEntry: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeFocusNodes();
    _trackExpressEntryRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeControllers();
      // Auto-select first delivery company if available
      _autoSelectFirstDeliveryCompany();
      // Auto-select first vendor category if available
      _autoSelectFirstVendorCategory();
      // Use setState if any UI updates are required after initialization
      setState(() {});
    });
    _initSpeech();
    _initializeBloc();
    _loadInitialData();
    _initializeCameras();
  }

  void _initializeFocusNodes() {
    _guestNameFocusNode = FocusNode();
    _guestComingFromFocusNode = FocusNode();
    _visitorNumberFocusNode = FocusNode();
    _carNumberFocusNode = FocusNode();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  Future<void> _initializeCameras() async {
    cachedCameras ??= await availableCameras();
  }

  Future<void> _initializeControllers() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch the stored "coming from" value
    final comingFrom = prefs.getString('visitor_coming_from');

    log("Fetched Coming From: $comingFrom"); // Log fetched value

    // Clear the stored value immediately after fetching
    await prefs.remove('visitor_coming_from');

    log("visitor_coming_from removed from SharedPreferences");

    // Initialize controllers with the fetched data
    // If coming from QR scan, use the provided guestname, otherwise use searched visitor name
    String guestName = "";
    if (widget.isFromQRScan && widget.guestname != null) {
      guestName = widget.guestname!;
    } else {
      guestName = widget.searchedVisitor?.name ?? "";
    }

    _guestNameController = TextEditingController(text: guestName);

    // Set coming from value based on source
    String comingFromValue = "";
    if (widget.isFromQRScan && widget.visitorLog?.visitor_coming_from != null) {
      comingFromValue = widget.visitorLog!.visitor_coming_from!;
    } else if (widget.searchedVisitor != null) {
      comingFromValue = comingFrom ?? widget.comingfrom ?? "";
    }

    _guestComingFromController = TextEditingController(text: comingFromValue);

    // Update coming from with value from gateStorage only if we have a searched visitor
    if (widget.searchedVisitor != null && !widget.isFromQRScan) {
      _guestComingFromController!.text =
          await gateStorage.getComingFrom() ?? "";
    }

    // Initialize guest count from visitorLog if available, otherwise default to 1
    final int initialGuestCount = widget.visitorLog?.visitor_count ?? 1;
    _guestCount = initialGuestCount;
    _guestCountController = TextEditingController(
      text: initialGuestCount.toString(),
    );
    _visitorNumberController = TextEditingController();
    _carNumberController = TextEditingController();
  }

  void _initializeBloc() {
    _bloc = VisitorInEntryBloc(
      VisitorUsecase(VisitorRepoImpl(remoteDataSource)),
      VisitorLogUsecase(VisitorLogRepositoryImpl(remoteDataSource)),
    );
  }

  final GateStorage gateStorage = GateStorage();
  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadVisitorSettings(),
      _loadSelectedPurposes(),
    ]);
  }

  Future<void> _updateVisitor(Visitor visitor) async {
    await remoteDataSource.updateVisitor(visitor);
  }

  Future<void> _loadVisitorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitorCardNumber = prefs.getBool('visitorCardNumber');
      _visitorAddress = prefs.getBool('visitorsAddress');
    });
  }

  Future<void> _loadSelectedPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_purposes');
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          _globalSelectedPurposes = jsonList
              .map((json) => PurposeCategoryMapper.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading purposes: $e');
    }
  }

  Future<String?> _handleMicPress(String field) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const ListeningDialog(),
    );

    if (result != null) {
      setState(() {
        switch (field) {
          case 'guestName':
            _guestNameController?.text = result;
            break;
          case 'guestComingFrom':
            _guestComingFromController?.text = result;
            break;
          case 'cabnumber':
            _carNumberController?.text = result;
            break;
        }
      });
    }
    return result;
  }

  void _incrementGuestCount() {
    if (_guestCount < 99) {
      setState(() {
        _guestCount++;
        _guestCountController?.text = _guestCount.toString();
      });
    }
  }

  void _decrementGuestCount() {
    if (_guestCount > 1) {
      setState(() {
        _guestCount--;
        _guestCountController?.text = _guestCount.toString();
      });
    }
  }

  final RemoteDataSource _remoteDataSource = RemoteDataSource();

  Future<File?> _captureImageFromCamera(BuildContext context) async {
    CameraController? cameraController;

    try {
      // Check camera permission first
      final cameraPermission = await Permission.camera.status;
      if (cameraPermission.isDenied) {
        final permissionResult = await Permission.camera.request();
        if (permissionResult.isDenied || permissionResult.isPermanentlyDenied) {
          _showEnhancedErrorToast(
            'Camera Permission Required',
            'Please enable camera permission in settings to take photos',
            Icons.camera_alt_outlined,
          );
          return null;
        }
      }

      final cameraProvider =
          Provider.of<CameraSettingsProvider>(context, listen: false);
      final selectedCameraValue = cameraProvider.selectedCameraValue;

      // Fetch available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showEnhancedErrorToast(
          'Camera Not Available',
          'No cameras found on this device',
          Icons.camera_alt_outlined,
        );
        return null;
      }

      late CameraDescription selectedCamera;

      // Select the appropriate camera
      // For express entry (self check-in flow), always use front camera for face verification
      if (widget.selfcheckinFlow) {
        try {
          selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          );
          print('📷 Express Entry: Using front camera for face verification');
        } catch (e) {
          // Fallback to back camera if front camera not available
          selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
          _showEnhancedErrorToast(
            'Front Camera Unavailable',
            'Using back camera instead for face verification',
            Icons.camera_alt_outlined,
          );
        }
      } else if (selectedCameraValue == 'front') {
        try {
          selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          );
        } catch (e) {
          // Fallback to back camera if front camera not available
          selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
          _showEnhancedErrorToast(
            'Front Camera Unavailable',
            'Using back camera instead',
            Icons.camera_alt_outlined,
          );
        }
      } else {
        try {
          selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
          );
        } catch (e) {
          // Fallback to front camera if back camera not available
          selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );
          _showEnhancedErrorToast(
            'Back Camera Unavailable',
            'Using front camera instead',
            Icons.camera_alt_outlined,
          );
        }
      }

      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      // Initialize camera with timeout
      await cameraController.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera initialization timeout');
        },
      );

      if (!mounted) return null;

      final XFile? image = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(
          builder: (context) => widget.selfcheckinFlow
              ? FaceLivenessCameraScreen(
                  cameraController: cameraController!,
                  isExpressEntry: true,
                )
              : CameraPreviewScreen(cameraController: cameraController!),
        ),
      );

      // Check if the user captured an image
      if (image != null) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final String imagePath =
            await _getNextIncrementalFilename(appDocDir.path);

        final File localImage = File(imagePath);
        await File(image.path).copy(localImage.path);

        print(
            "Image saved as: ${localImage.path.split('/').last}"); // Only prints filename
        return localImage;
      } else {
        // User cancelled - this is normal, no need for error toast
        print('Camera capture was cancelled by user');
        return null;
      }
    } catch (e) {
      print('Error capturing image: $e');

      // Show appropriate error message based on error type
      String errorTitle = 'Camera Error';
      String errorMessage = 'Failed to capture image';

      if (e.toString().contains('timeout')) {
        errorTitle = 'Camera Initialization Failed';
        errorMessage = 'Camera took too long to initialize. Please try again.';
      } else if (e.toString().contains('Permission')) {
        errorTitle = 'Permission Error';
        errorMessage = 'Camera permission is required to take photos';
      } else if (e.toString().contains('not available')) {
        errorTitle = 'Camera Unavailable';
        errorMessage = 'The selected camera is not available on this device';
      } else {
        errorMessage = 'An unexpected error occurred: ${e.toString()}';
      }

      _showEnhancedErrorToast(
        errorTitle,
        errorMessage,
        Icons.error_outline,
      );
      return null;
    } finally {
      try {
        await cameraController?.dispose();
      } catch (e) {
        print('Error disposing camera controller: $e');
      }
    }
  }

  /// Function to generate the next incremental filename like `image1.jpg`, `image2.jpg`
  Future<String> _getNextIncrementalFilename(String directoryPath) async {
    int counter = 1;
    String filePath;

    do {
      filePath = '$directoryPath/image$counter.jpg';
      counter++;
    } while (await File(filePath).exists());

    return filePath;
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    // Validate form first before any API calls (including DELIVERY company)
    if (!_validateForm()) {
      setState(() => _isSubmitting = false);
      return;
    }

    if (widget.selectedValue?.categoryName == 'DELIVERY' &&
        selectedCompanyIndex == -1) {
      _showErrorSnackBar(context.tr("Please select a delivery company."));
      setState(() => _isSubmitting = false);
      return;
    }

    // Only create visitor after all validations pass - prevents "visitor in" on incomplete submission
    log("_remoteDataSource.createVisitor");
    widget.searchedVisitor?.name = _guestNameController?.text;
    widget.searchedVisitor?.mobile = widget.searchedVisitor?.mobile != ""
        ? widget.searchedVisitor?.mobile
        : widget.mobile;

    final effectiveMobile = widget.searchedVisitor?.mobile?.isNotEmpty == true
        ? widget.searchedVisitor!.mobile
        : widget.mobile;

    Visitor? thisvisitor;
    try {
      thisvisitor = await _remoteDataSource.createVisitor(Visitor(
        name: _guestNameController?.text,
        mobile: effectiveMobile,
        isStaff: widget.searchedVisitor?.isStaff,
      ));
    } catch (e) {
      _showErrorSnackBar(context.tr('Failed to create visitor: {error}',
          params: {'error': e.toString()}));
      setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('visitor_coming_from');
      log(widget.mobile);
      final effectiveVisitor = thisvisitor ?? widget.searchedVisitor;
      log("effectiveVisitor: ${effectiveVisitor?.id}");
      prefs.setString(
          'search_visitor_id', effectiveVisitor?.id.toString() ?? "");
      _bloc.add(VIEGuestFormSubmitButtonPressedEvent(
        searchedVisitor: effectiveVisitor,
        guestName: _guestNameController?.text,
        guestComingFrom: _guestComingFromController?.text ?? "",
        guestCount: _guestCount,
        carNumber: _carNumberController?.text,
        purposeCategory: widget.selectedValue!,
        mobile: widget.mobile,
      ));

      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      _showErrorSnackBar(context
          .tr('An error occurred: {error}', params: {'error': e.toString()}));
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validateForm() {
    // Check if purpose is VENDOR
    if (widget.selectedValue?.categoryName == 'VENDOR') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _bloc.add(VIEValidationErrorEvent(
          message: AppLocalizations.of(context).enterVendorName,
          field: 'Vendor Name Required',
        ));
        return false;
      }
      if (selectedCompanyIndex == -1) {
        _bloc.add(VIEValidationErrorEvent(
          message: context.tr('Please select a vendor category to proceed'),
          field: 'Category Selection Required',
        ));
        return false;
      }
    }

    // Check if purpose is CABS
    else if (widget.selectedValue?.categoryName == 'CABS') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _bloc.add(VIEValidationErrorEvent(
          message: AppLocalizations.of(context).enterCabDriverName,
          field: 'Cab Driver Name Required',
        ));
        return false;
      }
      if ((_carNumberController?.text ?? "").isEmpty) {
        _bloc.add(VIEValidationErrorEvent(
          message: context.tr('Please enter the vehicle registration number'),
          field: 'Cab Number Required',
        ));
        return false;
      }
    }

    // Check if purpose is DELIVERY
    else if (widget.selectedValue?.categoryName == 'DELIVERY') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _bloc.add(VIEValidationErrorEvent(
          message: AppLocalizations.of(context).enterDeliveryPersonName,
          field: 'Delivery Person Required',
        ));
        return false;
      }
      if (selectedCompanyIndex == -1) {
        _bloc.add(VIEValidationErrorEvent(
          message: context.tr('Please select a delivery company to proceed'),
          field: 'Company Selection Required',
        ));
        return false;
      }
    }

    // Check if purpose is GUEST
    else if (widget.selectedValue?.categoryName == 'GUEST') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _bloc.add(VIEValidationErrorEvent(
          message: AppLocalizations.of(context).enterGuestName,
          field: 'Guest Name Required',
        ));
        return false;
      }
      if ((_guestComingFromController?.text ?? "").isEmpty &&
          _visitorAddress == true) {
        _bloc.add(VIEValidationErrorEvent(
          message: context.tr('Please enter where the guest is coming from'),
          field: 'Coming From Required',
        ));
        return false;
      }
      // Skip visitor card number validation for express entry flow
      if ((_visitorNumberController?.text ?? "").isEmpty &&
          _visitorCardNumber == true &&
          !widget.selfcheckinFlow) {
        _bloc.add(VIEValidationErrorEvent(
          message: context.tr('Please enter the visitor card number'),
          field: 'Card Number Required',
        ));
        return false;
      }
    }

    // Check if purpose is STAFF or MEMBER STAFF
    else if (widget.selectedValue?.categoryName == 'STAFF' ||
        widget.selectedValue?.categoryName == 'MEMBER STAFF') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _bloc.add(VIEValidationErrorEvent(
          message: AppLocalizations.of(context).enterStaffName,
          field: 'Staff Name Required',
        ));
        return false;
      }
      if ((_guestComingFromController?.text ?? "").isEmpty &&
          _visitorAddress == true) {
        _bloc.add(VIEValidationErrorEvent(
          message:
              context.tr('Please enter where the staff member is coming from'),
          field: 'Coming From Required',
        ));
        return false;
      }
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    myFluttertoast(msg: message, backgroundColor: Colors.red);
  }

  void _showEnhancedErrorToast(String title, String message, IconData icon,
      {FocusNode? focusNode}) {
    // Highlight the field if focus node is provided
    if (focusNode != null) {
      _highlightField(focusNode);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
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
        backgroundColor: const Color(0xffF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  void _highlightField(FocusNode focusNode) {
    focusNode.requestFocus();
  }

  void _autoSelectFirstDeliveryCompany() {
    final effectivePurpose = widget.selectedValue ??
        (_globalSelectedPurposes.isNotEmpty
            ? _globalSelectedPurposes.first
            : null);

    if (effectivePurpose?.categoryName == 'DELIVERY') {
      final subCategories = effectivePurpose?.subCategories;
      if (subCategories != null && subCategories.isNotEmpty) {
        setState(() {
          selectedCompanyIndex = 0;
          selectedSubCategoryId = subCategories.first.subCategoryId?.toString();
        });
      }
    }
  }

  void _autoSelectFirstVendorCategory() {
    final effectivePurpose = widget.selectedValue ??
        (_globalSelectedPurposes.isNotEmpty
            ? _globalSelectedPurposes.first
            : null);

    if (effectivePurpose?.categoryName == 'VENDOR') {
      final subCategories = effectivePurpose?.subCategories;
      if (subCategories != null && subCategories.isNotEmpty) {
        setState(() {
          selectedCompanyIndex = 0;
          selectedSubCategoryId = subCategories.first.subCategoryId?.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePurpose = widget.selectedValue ??
        (_globalSelectedPurposes.isNotEmpty
            ? _globalSelectedPurposes.first
            : null);

    if (effectivePurpose == null) {
      return Center(
          child: Text(AppLocalizations.of(context).noPurposeSelected));
    }

    return BlocConsumer<VisitorInEntryBloc, VisitorInEntryState>(
      bloc: _bloc,
      listenWhen: (previous, current) =>
          current is VisitorInEntryActionState ||
          current is VisitorInEntryErrorState ||
          current is VisitorInEntryValidationErrorState,
      buildWhen: (previous, current) =>
          current is! VisitorInEntryActionState &&
          current is! VisitorInEntryErrorState &&
          current is! VisitorInEntryValidationErrorState,
      listener: (context, state) async {
        if (state is VisitorInEntryErrorState) {
          _showErrorSnackBar(state.message);
          setState(() => _isSubmitting = false);
        } else if (state is VisitorInEntryValidationErrorState) {
          // Get the appropriate focus node based on the field
          FocusNode? focusNode;
          IconData icon = Icons.error_outline;

          switch (state.field.toLowerCase()) {
            case 'vendor name required':
            case 'cab driver name required':
            case 'delivery person required':
            case 'guest name required':
            case 'staff name required':
              focusNode = _guestNameFocusNode;
              icon = Icons.person_outline;
              break;
            case 'coming from required':
              focusNode = _guestComingFromFocusNode;
              icon = Icons.location_on_outlined;
              break;
            case 'card number required':
              focusNode = _visitorNumberFocusNode;
              icon = Icons.credit_card_outlined;
              break;
            case 'cab number required':
              focusNode = _carNumberFocusNode;
              icon = Icons.directions_car_outlined;
              break;
            case 'category selection required':
              icon = Icons.category_outlined;
              break;
            case 'company selection required':
              icon = Icons.local_shipping_outlined;
              break;
          }

          _showEnhancedErrorToast(
            state.field,
            state.message,
            icon,
            focusNode: focusNode,
          );
          setState(() => _isSubmitting = false);
        } else if (state is VIENavigateToUnitSelectionState) {
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          String? searchedId = prefs.getString('search_visitor_id');
          final visitorId = prefs.getString('visitorId');
          print(" searchid $searchedId");

          if (widget.searchedVisitor != null &&
              widget.searchedVisitor!.id != null) {
            final Visitor updatedVisitor = Visitor(
                id: searchedId == null
                    ? int.parse(visitorId.toString())
                    : int.parse(searchedId.toString()),
                name: _guestNameController?.text,
                mobile: widget.mobile,
                visitor_image: "",
                isStaff: widget.searchedVisitor?.isStaff);

            await _updateVisitor(updatedVisitor);
          }
          // Gatekeeper QR must go through unit selection - entry only after all details submitted.
          // Self-checkin QR can skip unit selection (express entry flow).
          if (widget.isFromQRScan &&
              widget.isGatekeeperQRPasscodeEntry != true) {
            // Trigger camera navigation by dispatching the camera event
            _bloc.add(VIENavigateToCameraEvent(
              purposeCategory: state.purposeCategory,
              visitor: state.visitor,
            ));
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitSelectionView(
                  widget.searchedVisitor,
                  visitor: state.visitor,
                  selfcheckinFlow: widget.selfcheckinFlow,
                  visitorId: widget.searchedVisitor?.id,
                  guestname: _guestNameController?.text ?? "",
                  mobileNumber: widget.mobile,
                  purposeCategory: state.purposeCategory,
                  purposeCategoryId:
                      widget.selectedValue?.categoryId.toString() ??
                          selectedCompanyIndex.toString(),
                  selectedSubCategoryId: selectedSubCategoryId,
                  comingFrom: _guestComingFromController?.text,
                  carNumber: _carNumberController?.text,
                  guestCount: _guestCount,
                  visitorNumber:
                      _visitorNumberController?.text.isNotEmpty == true
                          ? "V${_visitorNumberController!.text}"
                          : (_visitorNumberController?.text.isEmpty == true
                              ? null
                              : _visitorNumberController?.text),
                ),
              ),
            );
          }

          setState(() => _isSubmitting = false);
        } else if (state is VIENavigateToCameraState) {
          // Ensure camera state navigation is handled correctly
          final imageFile = await _captureImageFromCamera(context);

          if (imageFile != null) {
            // Dispatch the camera button pressed event
            final SharedPreferences prefs =
                await SharedPreferences.getInstance();
            var visitorId = prefs.getString('visitorId');
            state.visitor.id = int.parse(visitorId ?? "");
            _bloc.add(VIECameraButtonPressedEvent(
              purposeCategory: state.purposeCategory,
              imageFile: imageFile,
              visitor: state.visitor,
              operation: "update_visitor",
              isFromQRScan: widget.isFromQRScan,
              isGatekeeperQRPasscodeEntry: widget.isGatekeeperQRPasscodeEntry,
              visitorLog: widget.visitorLog,
            ));
          } else {
            // Camera capture failed or was cancelled
            // Error messages are already handled in _captureImageFromCamera method
            // Reset the submitting state to allow user to try again
            if (mounted) {
              setState(() => _isSubmitting = false);
            }
          }
        } else if (state is VIENavigateToRequestScreenState) {
          // Navigate to request screen after photo capture for QR scan flow
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RequestPermissionPage2(
                status: widget.selfcheckinFlow ? 1 : 0,
                visitor: state.visitor,
                visitorLog: state.visitorLog,
                request: 'allowByGatekeeper',
                logID: state.visitorLog.visitor?.id.toString(),
                selfcheckinFlow: widget.selfcheckinFlow,
                isGatekeeperQRPasscodeEntry: widget
                    .isGatekeeperQRPasscodeEntry, // Use the parameter to determine flow type
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is VisitorInEntryLoadingState) {
          return DashboardLoader(
            title: context.tr('Processing Visitor Details'),
            subtitle: context.tr('Please wait while we continue...'),
          );
        }

        return MyScrollView(
          isScrollable: true,
          pageTitle:
              '${AppLocalizations.of(context).purposeEntry} - ${effectivePurpose.categoryName}',
          pageBody: _buildPurposeForm(effectivePurpose),
          floatingActionButton: widget.selfcheckinFlow
              ? null
              : Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff212427), Color(0xff57636C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isSubmitting ? null : _handleSubmit,
                        child: Center(
                          child: Text(
                            _isSubmitting
                                ? 'Processing...'
                                : AppLocalizations.of(context).next,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPurposeForm(PurposeCategory1 purpose) {
    switch (purpose.categoryName.toUpperCase()) {
      case 'CABS':
        return _buildCabsForm();
      case 'DELIVERY':
        return _buildDeliveryForm(purpose);
      case 'GUEST':
        return _buildGuestForm();
      case 'VENDOR':
        return _buildVendorForm(purpose);
      case 'STAFF':
        return _buildStaffForm();
      case 'MEMBER STAFF':
        return _buildStaffForm();
      default:
        return Center(child: Text(AppLocalizations.of(context).unknownPurpose));
    }
  }

  Widget _buildStaffForm() {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xffF44336),
              ),
            ),
          );
        }

        // final prefs = snapshot.data!;
        // final staffJson = prefs.getString('search_staff_info');
        // if (staffJson == null) {
        //   return const Text("No staff data found.");
        // }
        //
        // final staffData = jsonDecode(staffJson);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Staff Form - Single Card with All Fields
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xff212427).withOpacity(0.12),
                  width: 0.9,
                ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Header Section
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
                            Icons.badge,
                            color: Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).staffInformation,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff212427),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)
                                    .pleaseFillStaffDetails,
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

                  // Staff Name Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: AppLocalizations.of(context).staffName,
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
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _guestNameController,
                          focusNode: _guestNameFocusNode,
                          textCapitalization: TextCapitalization.words,
                          cursorColor: const Color(0xffF44336),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff212427),
                          ),
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(context).enterStaffName,
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xff57636C),
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xffF44336).withOpacity(0.02),
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
                                width: 1.0,
                              ),
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              child: CircleAvatar(
                                backgroundColor:
                                    const Color(0xffF44336).withOpacity(0.1),
                                radius: 20,
                                child: IconButton(
                                  onPressed: () => _handleMicPress('guestName'),
                                  icon: const Icon(
                                    Icons.mic,
                                    size: 20,
                                    color: Color(0xffF44336),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Coming From Field
                  Container(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).comingFrom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff212427),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _guestComingFromController,
                          focusNode: _guestComingFromFocusNode,
                          textCapitalization: TextCapitalization.words,
                          cursorColor: const Color(0xffF44336),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff212427),
                          ),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)
                                .enterComingFromLocation,
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xff57636C),
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xffF44336).withOpacity(0.02),
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
                                width: 1.0,
                              ),
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              child: CircleAvatar(
                                backgroundColor:
                                    const Color(0xffF44336).withOpacity(0.1),
                                radius: 20,
                                child: IconButton(
                                  onPressed: () =>
                                      _handleMicPress('guestComingFrom'),
                                  icon: const Icon(
                                    Icons.mic,
                                    size: 20,
                                    color: Color(0xffF44336),
                                  ),
                                  padding: EdgeInsets.zero,
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
            ),

            // Bottom spacing
            const SizedBox(height: 120),

            // Add Next button for express entry flow only
            if (widget.selfcheckinFlow) _buildExpressEntryNextButton(),
          ],
        );
      },
    );
  }

  Widget _buildCabsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Cabs Form - Single Card with All Fields
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xff212427).withOpacity(0.12),
              width: 0.9,
            ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header Section
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
                        Icons.local_taxi,
                        color: Color(0xffF44336),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).cabInformation,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff212427),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).pleaseFillCabDetails,
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

              // Cab Driver Name Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: AppLocalizations.of(context).cabDriverName,
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
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _guestNameController,
                      focusNode: _guestNameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      cursorColor: const Color(0xffF44336),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff212427),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            AppLocalizations.of(context).enterCabDriverName,
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
                            width: 1.0,
                          ),
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor:
                                const Color(0xffF44336).withOpacity(0.1),
                            radius: 20,
                            child: IconButton(
                              onPressed: () => _handleMicPress('guestName'),
                              icon: const Icon(
                                Icons.mic,
                                size: 20,
                                color: Color(0xffF44336),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cab Number Field
              Container(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: AppLocalizations.of(context).cabNumber,
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
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _carNumberController,
                      focusNode: _carNumberFocusNode,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 10,
                      cursorColor: const Color(0xffF44336),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff212427),
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('MH 12 AB 1234'),
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
                            width: 1.0,
                          ),
                        ),
                        counterText: '', // Hide character counter
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor:
                                const Color(0xffF44336).withOpacity(0.1),
                            radius: 20,
                            child: IconButton(
                              onPressed: () => _handleMicPress('cabnumber'),
                              icon: const Icon(
                                Icons.mic,
                                size: 20,
                                color: Color(0xffF44336),
                              ),
                              padding: EdgeInsets.zero,
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
        ),

        // Bottom spacing
        const SizedBox(height: 120),

        // Add Next button for express entry flow only
        if (widget.selfcheckinFlow) _buildExpressEntryNextButton(),
      ],
    );
  }

  Widget _buildDeliveryForm(PurposeCategory1 purpose) {
    final subCategories = purpose.subCategories;
    if (subCategories == null || subCategories.isEmpty) {
      return Center(
          child: Text(context.tr('No delivery companies available.')));
    }

    // Reorder subcategories to put "Others" at the end
    final reorderedSubCategories = <SubCategory>[];
    SubCategory? othersCategory;

    // First, add all non-"Others" categories
    for (final subCategory in subCategories) {
      if (subCategory.subCategoryName?.toLowerCase().contains('others') ==
              true ||
          subCategory.subCategoryName?.toLowerCase().contains('other') ==
              true) {
        othersCategory = subCategory;
      } else {
        reorderedSubCategories.add(subCategory);
      }
    }

    // Then add "Others" at the end if it exists
    if (othersCategory != null) {
      reorderedSubCategories.add(othersCategory);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Delivery Person Name Field Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xff212427).withOpacity(0.12),
              width: 0.9,
            ),
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
                        Icons.person,
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
                                      .deliveryPersonName,
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
                                .enterNameOfDeliveryPerson,
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
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: TextFormField(
                  controller: _guestNameController,
                  focusNode: _guestNameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: const Color(0xffF44336),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff212427),
                  ),
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context).enterDeliveryPersonName,
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
                        width: 1.0,
                      ),
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor:
                            const Color(0xffF44336).withOpacity(0.1),
                        radius: 20,
                        child: IconButton(
                          onPressed: () => _handleMicPress('guestName'),
                          icon: const Icon(
                            Icons.mic,
                            size: 20,
                            color: Color(0xffF44336),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Enhanced Company Selection Header
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          child: Row(
            children: [
              // Delivery Icon (matching delivery person name icon style)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xffF44336).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Color(0xffF44336),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).selectDeliveryCompany,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff212427),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Enhanced Company Selection Grid
        GridView.builder(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: reorderedSubCategories.length,
          itemBuilder: (context, index) {
            final subCategory = reorderedSubCategories[index];
            final isSelected = index == selectedCompanyIndex;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  selectedCompanyIndex = index;
                  selectedSubCategoryId = subCategory.subCategoryId?.toString();
                  log("Selected Index: $index");
                  log("Selected SubCategoryId: $selectedSubCategoryId");
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xffF44336)
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 1 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Enhanced Company Logo Container
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: subCategory.image ?? '',
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: DashboardLoaderIcon(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xffF44336),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.local_shipping,
                            color: Color(0xffF44336),
                            size: 32,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Enhanced Company Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        subCategory.subCategoryName ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xffF44336)
                              : const Color(0xff212427),
                        ),
                      ),
                    ),

                    // Selection Indicator
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xffF44336),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Bottom spacing
        const SizedBox(height: 120),

        // Add Next button for express entry flow only
        if (widget.selfcheckinFlow) _buildExpressEntryNextButton(),
      ],
    );
  }

  Widget _buildVendorForm(PurposeCategory1 purpose) {
    final subCategories = purpose.subCategories;
    if (subCategories == null || subCategories.isEmpty) {
      return Center(child: Text(context.tr('No vendor categories available.')));
    }

    // Reorder subcategories to put "Others" at the end
    final reorderedSubCategories = <SubCategory>[];
    SubCategory? othersCategory;

    // First, add all non-"Others" categories
    for (final subCategory in subCategories) {
      if (subCategory.subCategoryName?.toLowerCase().contains('others') ==
              true ||
          subCategory.subCategoryName?.toLowerCase().contains('other') ==
              true) {
        othersCategory = subCategory;
      } else {
        reorderedSubCategories.add(subCategory);
      }
    }

    // Then add "Others" at the end if it exists
    if (othersCategory != null) {
      reorderedSubCategories.add(othersCategory);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Vendor Name Field Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xff212427).withOpacity(0.12),
              width: 0.9,
            ),
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
                        Icons.business,
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
                                  text: AppLocalizations.of(context).vendorName,
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
                            AppLocalizations.of(context).enterNameOfVendor,
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
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: TextFormField(
                  controller: _guestNameController,
                  focusNode: _guestNameFocusNode,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: const Color(0xffF44336),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff212427),
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).enterVendorName,
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
                        width: 1.0,
                      ),
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor:
                            const Color(0xffF44336).withOpacity(0.1),
                        radius: 20,
                        child: IconButton(
                          onPressed: () => _handleMicPress('guestName'),
                          icon: const Icon(
                            Icons.mic,
                            size: 20,
                            color: Color(0xffF44336),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Enhanced Vendor Category Selection Header
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          child: Row(
            children: [
              // Vendor Icon (matching vendor name icon style)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xffF44336).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category,
                  color: Color(0xffF44336),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).selectVendorCategory,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff212427),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Enhanced Vendor Category Selection Grid
        GridView.builder(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.85,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: reorderedSubCategories.length,
          itemBuilder: (context, index) {
            final subCategory = reorderedSubCategories[index];
            final isSelected = index == selectedCompanyIndex;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  selectedCompanyIndex = index;
                  selectedSubCategoryId = subCategory.subCategoryId?.toString();
                  log("Selected Index: $index");
                  log("Selected SubCategoryId: $selectedSubCategoryId");
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xffF44336)
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 1 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Enhanced Vendor Category Logo Container
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: subCategory.image ?? '',
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: DashboardLoaderIcon(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xffF44336),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.business,
                            color: Color(0xffF44336),
                            size: 32,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Enhanced Vendor Category Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        subCategory.subCategoryName ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xffF44336)
                              : const Color(0xff212427),
                        ),
                      ),
                    ),

                    // Selection Indicator
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xffF44336),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Bottom spacing
        const SizedBox(height: 120),

        // Add Next button for express entry flow only
        if (widget.selfcheckinFlow) _buildExpressEntryNextButton(),
      ],
    );
  }

  Widget _buildGuestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Guest Form - Single Card with All Fields
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xff212427).withOpacity(0.12),
              width: 0.9,
            ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Header Section
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
                        Icons.person,
                        color: Color(0xffF44336),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).guestInformation,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff212427),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).pleaseFillGuestDetails,
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

              // Guest Name Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: AppLocalizations.of(context).guestName,
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
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _guestNameController,
                      focusNode: _guestNameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      cursorColor: const Color(0xffF44336),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff212427),
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).enterGuestName,
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
                            width: 1.0,
                          ),
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor:
                                const Color(0xffF44336).withOpacity(0.1),
                            radius: 20,
                            child: IconButton(
                              onPressed: () => _handleMicPress('guestName'),
                              icon: const Icon(
                                Icons.mic,
                                size: 20,
                                color: Color(0xffF44336),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Coming From Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: AppLocalizations.of(context).comingFrom,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff212427),
                            ),
                          ),
                          if (_visitorAddress == true)
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
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _guestComingFromController,
                      focusNode: _guestComingFromFocusNode,
                      textCapitalization: TextCapitalization.words,
                      cursorColor: const Color(0xffF44336),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff212427),
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                            .enterComingFromLocation,
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
                            width: 1.0,
                          ),
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            backgroundColor:
                                const Color(0xffF44336).withOpacity(0.1),
                            radius: 20,
                            child: IconButton(
                              onPressed: () =>
                                  _handleMicPress('guestComingFrom'),
                              icon: const Icon(
                                Icons.mic,
                                size: 20,
                                color: Color(0xffF44336),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Visitor ID Field (if enabled and NOT from QR/Passcode or Express Entry)
              // Show only for Gatekeeper Mobile Number flow when visitor card entry is enabled
              if (_visitorCardNumber == true &&
                  !widget.selfcheckinFlow &&
                  !widget.isFromQRScan) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(context).visitorId,
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
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _visitorNumberController,
                        focusNode: _visitorNumberFocusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        cursorColor: const Color(0xffF44336),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff212427),
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).enterVisitorId,
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
                              width: 1.0,
                            ),
                          ),
                          counterText: '', // Hide character counter
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xffF44336).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  "V",
                                  style: TextStyle(
                                    color: Color(0xffF44336),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
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
              ],

              const SizedBox(height: 20),

              // Guest Count Field
              Container(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guest Count',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff212427),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _guestCountController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      cursorColor: const Color(0xffF44336),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff212427),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _guestCount = int.tryParse(value) ?? 1;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: context.tr('Guest count'),
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
                            width: 1.0,
                          ),
                        ),
                        counterText: '', // Hide character counter
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _decrementGuestCount,
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Color(0xffF44336),
                                  size: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                onPressed: _incrementGuestCount,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.green,
                                  size: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom spacing
        const SizedBox(height: 120),

        // Add Next button for express entry flow only
        if (widget.selfcheckinFlow) _buildExpressEntryNextButton(),
      ],
    );
  }

  Widget _buildMicButton(Future<void> Function() onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: CircleAvatar(
        backgroundColor: const Color(0xffF44336).withOpacity(0.1),
        radius: 20,
        child: const Icon(
          Ionicons.mic_outline,
          size: 22,
          color: Color(0xffF44336),
        ),
      ),
    );
  }

  // Build responsive Next button for express entry flow
  Widget _buildExpressEntryNextButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth >= 360 && screenWidth < 768;
    final isTablet = screenWidth >= 768;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallMobile
            ? 16
            : isMobile
                ? 20
                : 24,
        vertical: isSmallMobile
            ? 16
            : isMobile
                ? 20
                : 24,
      ),
      child: Container(
        width: double.infinity,
        height: isSmallMobile
            ? 56
            : isMobile
                ? 60
                : isTablet
                    ? 64
                    : 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff212427), Color(0xff57636C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(
            isSmallMobile
                ? 16
                : isMobile
                    ? 18
                    : 20,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: isSmallMobile ? 12 : 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: isSmallMobile ? 6 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(
              isSmallMobile
                  ? 16
                  : isMobile
                      ? 18
                      : 20,
            ),
            onTap: _isSubmitting ? null : _handleSubmit,
            child: Center(
              child: Text(
                _isSubmitting
                    ? context.tr('Processing...')
                    : AppLocalizations.of(context).next,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallMobile
                      ? 18
                      : isMobile
                          ? 20
                          : isTablet
                              ? 22
                              : 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitorIdPrefix() {
    return Container(
      width: 20,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xffFFEBE6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Center(child: Text(context.tr('visitorIdBadgeLetter'))),
    );
  }

  Widget _buildGuestCountField() {
    final l10n = AppLocalizations.of(context);
    return CustomForm.textField(
      l10n.guestCount,
      textController: _guestCountController,
      hintText: l10n.guestCount,
      keyboardType: TextInputType.number,
      titleColor: Theme.of(context).colorScheme.onSurface,
      hintColor: Theme.of(context).colorScheme.onPrimary,
      length: 2,
      onChanged: (value) {
        setState(() {
          _guestCount = int.tryParse(value) ?? 1;
        });
      },
      suffixIcon: OverflowBar(
        children: [
          IconButton(
            onPressed: _decrementGuestCount,
            icon: const Icon(
              Ionicons.remove_circle_outline,
              color: Color(0xffF44336),
              size: 32,
            ),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: _incrementGuestCount,
            icon: const Icon(
              Ionicons.add_circle_outline,
              size: 32,
              color: Colors.green,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  String? _validateVisitorId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your ID';
    }
    if (value.length != 4) {
      return 'ID must be 4 digits';
    }
    return null;
  }

  @override
  void dispose() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('visitor_coming_from');
      prefs.remove('visitorId');

      debugPrint(
          "----------------------------------->>>>>>>>>--------${prefs.remove('visitorId')}");
    });

    _guestNameController?.dispose();
    _guestComingFromController?.dispose();
    _guestCountController?.dispose();
    _visitorNumberController?.dispose();
    _carNumberController?.dispose();

    // Dispose focus nodes
    _guestNameFocusNode?.dispose();
    _guestComingFromFocusNode?.dispose();
    _visitorNumberFocusNode?.dispose();
    _carNumberFocusNode?.dispose();

    super.dispose();
  }
}

class SelectTypeWidget extends StatefulWidget {
  const SelectTypeWidget({super.key});

  @override
  State<SelectTypeWidget> createState() => _SelectTypeWidgetState();
}

class _SelectTypeWidgetState extends State<SelectTypeWidget> {
  int selectedUserInput = -1;

  final List<String> imagePaths = [
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/admin_7307678f4d.png?updated_at=2023-08-31T12:10:09.789Z',
  ];

  final List<String> imageValues = [
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
  ];

  void selectImage(int index) {
    setState(() {
      selectedUserInput = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 3,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => selectImage(index),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: selectedUserInput == index
                  ? const Color(0xffFFEBE6)
                  : Colors.transparent,
              border: Border.all(
                color: selectedUserInput == index
                    ? Colors.red
                    : Colors.transparent,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    imageValues[index],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ListeningDialog extends StatefulWidget {
  const ListeningDialog({super.key});

  @override
  ListeningDialogState createState() => ListeningDialogState();
}

class ListeningDialogState extends State<ListeningDialog>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String recognizedText = 'Listening...';
  bool _hasRecognizedText = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startListening();
  }

  Future<void> _startListening() async {
    setState(() {
      _hasRecognizedText = false;
      recognizedText = 'Listening...';
    });

    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        print('Error: $error');
        setState(() {
          recognizedText = 'Error occurred. Please try again.';
          _isListening = false;
        });
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              recognizedText = result.recognizedWords;
              _hasRecognizedText = true;
            }
            if (result.finalResult) {
              _isListening = false;
            }
          });
        },
      );
    } else {
      setState(() {
        recognizedText = 'Speech recognition not available';
        _isListening = false;
      });
    }
  }

  void _retryListening() {
    _stopListening();
    _startListening();
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _speechToText.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffF44336).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.hearing,
                  size: 32,
                  color: Color(0xffF44336),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                'Voice Recognition',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff212427),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Recognized text with enhanced styling
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xffF44336).withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  recognizedText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _hasRecognizedText
                        ? const Color(0xff212427)
                        : const Color(0xff57636C),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                ),
              ),

              const SizedBox(height: 24),

              // Enhanced microphone button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isListening
                      ? const LinearGradient(
                          colors: [Color(0xffF44336), Color(0xffD32F2F)],
                        )
                      : null,
                  color: _isListening
                      ? null
                      : const Color(0xffF44336).withOpacity(0.1),
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: const Color(0xffF44336).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) => Transform.scale(
                    scale: _isListening ? _animation.value : 1.0,
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 40,
                        color: _isListening
                            ? Colors.white
                            : const Color(0xffF44336),
                      ),
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                      padding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Enhanced action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_hasRecognizedText)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ElevatedButton.icon(
                          onPressed: _retryListening,
                          icon: const Icon(Icons.refresh,
                              size: 20, color: Color(0xffF44336)),
                          label: Text(AppLocalizations.of(context).retry),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xffF44336),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: const Color(0xffF44336).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(left: _hasRecognizedText ? 8 : 0),
                      child: ElevatedButton(
                        onPressed: () {
                          _stopListening();
                          if (_hasRecognizedText) {
                            Navigator.of(context).pop(recognizedText);
                          } else {
                            Navigator.of(context).pop(null);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasRecognizedText
                              ? const Color(0xffF44336)
                              : const Color(0xff57636C),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _hasRecognizedText ? 'Done' : 'Cancel',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraPreviewScreen extends StatefulWidget {
  final CameraController cameraController;

  const CameraPreviewScreen({
    Key? key,
    required this.cameraController,
  }) : super(key: key);

  @override
  _CameraPreviewScreenState createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  late CameraDescription _currentCamera;
  XFile? _capturedImage;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentCamera = widget.cameraController.description;
    _cameraController = widget.cameraController;
    _lockCameraToPortrait();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _lockCameraToPortrait() async {
    if (_cameraController.value.isInitialized) {
      await _cameraController
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
  }

  Future<void> _switchCamera() async {
    try {
      final cameras = await availableCameras();
      final CameraDescription newCamera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (_currentCamera.lensDirection == CameraLensDirection.front
                ? CameraLensDirection.back
                : CameraLensDirection.front),
      );

      await _cameraController.dispose();

      final CameraController newController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await newController.initialize();
      await newController.lockCaptureOrientation(DeviceOrientation.portraitUp);

      setState(() {
        _cameraController = newController;
        _currentCamera = newCamera;
        _capturedImage = null;
      });
    } catch (e) {
      print('Error switching cameras: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final double previewMargin = isTablet ? 24 : 8;
    final double previewRadius = isTablet ? 32 : 20;
    const double previewBorder = 3;
    const double previewShadow = 32;
    const double previewAspectRatio = 3 / 4;
    final double controlsHeight = isTablet ? 120 : 90;
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Hide back button
          title: const Text(
            'Take Photo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: previewAspectRatio,
                    child: Container(
                      margin: EdgeInsets.all(previewMargin),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(previewRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: previewShadow,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: previewBorder,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _capturedImage == null
                          ? CameraPreview(_cameraController)
                          : Image.file(
                              File(_capturedImage!.path),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: isTablet ? 32 : 16, top: 8),
                child: _capturedImage == null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            onPressed: _switchCamera,
                            icon: Icons.flip_camera_ios_rounded,
                            size: isTablet ? 40 : 30,
                          ),
                          GestureDetector(
                            onTap: _isCapturing
                                ? null
                                : () async {
                                    setState(() => _isCapturing = true);
                                    try {
                                      final image =
                                          await _cameraController.takePicture();
                                      setState(() {
                                        _capturedImage = image;
                                        _isCapturing = false;
                                      });
                                    } catch (e) {
                                      print('Error capturing image: $e');
                                      setState(() => _isCapturing = false);
                                    }
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: controlsHeight,
                              width: controlsHeight,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      _isCapturing ? Colors.grey : Colors.white,
                                  width: 4,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.grey[200]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: isTablet ? 40 : 30),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            onPressed: () {
                              setState(() => _capturedImage = null);
                            },
                            icon: Icons.refresh,
                            size: isTablet ? 40 : 30,
                          ),
                          _buildControlButton(
                            onPressed: () {
                              Navigator.pop(context, _capturedImage);
                            },
                            icon: Icons.check,
                            size: isTablet ? 40 : 30,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    double size = 24,
  }) {
    return Container(
      height: size + 20,
      width: size + 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black26,
        border: Border.all(color: Colors.white54, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: size),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
