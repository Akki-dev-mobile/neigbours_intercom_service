import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/entity/purpose_mapper.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../units_selection/ui/unit_selection_view.dart';
import '../bloc/visitor_in_entry_bloc.dart';

class VisitorsInEntry extends StatefulWidget {
  final PurposeCategory1? selectedValue;
  final Visitor? searchedVisitor;
  final String mobile;

  const VisitorsInEntry({
    Key? key,
    this.selectedValue,
    this.searchedVisitor,
    required this.mobile,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeControllers();
      // Use setState if any UI updates are required after initialization
      setState(() {});
    });
    _initSpeech();
    _initializeBloc();
    _loadInitialData();
    _initializeCameras();
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
    final comingFrom = prefs.getString('visitor_coming_from') ?? "";

    log("Fetched Coming From: $comingFrom"); // Log fetched value

    // Clear the stored value immediately after fetching
    await prefs.remove('visitor_coming_from');

    log("visitor_coming_from removed from SharedPreferences");

    // Initialize controllers with the fetched data
    _guestNameController = TextEditingController(
      text: widget.searchedVisitor?.name ?? "",
    );
    _guestComingFromController = TextEditingController(
      text: comingFrom,
    );
    _guestCountController = TextEditingController(
      text: '1',
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

  Future<File?> _captureImageFromCamera(BuildContext context) async {
    CameraController? cameraController;

    try {
      final cameraProvider =
          Provider.of<CameraSettingsProvider>(context, listen: false);
      final selectedCameraValue = cameraProvider.selectedCameraValue;

      // Fetch available cameras
      final cameras = await availableCameras();
      late CameraDescription selectedCamera;

      // Select the appropriate camera
      if (selectedCameraValue == 'front') {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => throw Exception('Front camera not available'),
        );
      } else {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => throw Exception('Back camera not available'),
        );
      }

      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
      );
      await cameraController.initialize();

      final XFile? image = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CameraPreviewScreen(cameraController: cameraController!),
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
        print("No image captured");
        return null;
      }
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    } finally {
      await cameraController?.dispose();
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

    if (!_validateForm()) return;

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    if (widget.selectedValue?.categoryName == 'DELIVERY' &&
        selectedCompanyIndex == -1) {
      _showErrorSnackBar("Please select a delivery company.");
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      return;
    }

    try {
      // Clear the stored coming from value after submission
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('visitor_coming_from');

      _bloc.add(VIEGuestFormSubmitButtonPressedEvent(
        searchedVisitor: widget.searchedVisitor,
        guestName: _guestNameController?.text,
        guestComingFrom: _guestComingFromController?.text ?? "",
        guestCount: _guestCount,
        carNumber: _carNumberController?.text,
        purposeCategory: widget.selectedValue!,
        mobile: widget.mobile,
      ));

      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      _showErrorSnackBar('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validateForm() {
    // Check if purpose is VENDOR
    if (widget.selectedValue?.categoryName == 'VENDOR') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _showErrorSnackBar('Please enter vendor name');
        return false;
      }
      if ((_guestComingFromController?.text ?? "").isEmpty &&
          _visitorAddress == true) {
        _showErrorSnackBar('Please enter coming from');
        return false;
      }
      if (selectedCompanyIndex == -1) {
        _showErrorSnackBar('Please select a vendor category');
        return false;
      }
    }

    // Check if purpose is CABS
    else if (widget.selectedValue?.categoryName == 'CABS') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _showErrorSnackBar('Please enter cab driver name');
        return false;
      }
      if ((_carNumberController?.text ?? "").isEmpty) {
        _showErrorSnackBar('Please enter cab number');
        return false;
      }
    }

    // Check if purpose is DELIVERY
    else if (widget.selectedValue?.categoryName == 'DELIVERY') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _showErrorSnackBar('Please enter delivery person name');
        return false;
      }
      if (selectedCompanyIndex == -1) {
        _showErrorSnackBar('Please select a delivery company');
        return false;
      }
    }

    // Check if purpose is GUEST
    else if (widget.selectedValue?.categoryName == 'GUEST') {
      if ((_guestNameController?.text ?? "").isEmpty) {
        _showErrorSnackBar('Please enter guest name');
        return false;
      }
      if ((_guestComingFromController?.text ?? "").isEmpty &&
          _visitorAddress == true) {
        _showErrorSnackBar('Please enter coming from');
        return false;
      }
      if ((_visitorNumberController?.text ?? "").isEmpty &&
          _visitorCardNumber == true) {
        _showErrorSnackBar('Please enter card number');
        return false;
      }
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    myFluttertoast(msg: message, backgroundColor: Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    final effectivePurpose = widget.selectedValue ??
        (_globalSelectedPurposes.isNotEmpty
            ? _globalSelectedPurposes.first
            : null);

    if (effectivePurpose == null) {
      return const Center(child: Text("No purpose selected or available."));
    }

    return BlocConsumer<VisitorInEntryBloc, VisitorInEntryState>(
      bloc: _bloc,
      listenWhen: (previous, current) => current is VisitorInEntryActionState,
      buildWhen: (previous, current) => current is! VisitorInEntryActionState,
      listener: (context, state) async {
        if (state is VisitorInEntryErrorState) {
          _showErrorSnackBar(state.message);
          setState(() => _isSubmitting = false);
        } else if (state is VIENavigateToUnitSelectionState) {
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          final searched_id = await prefs.getString('search_visitor_id');
          print(" searchid $searched_id");

          if (widget.searchedVisitor != null) {
            final Visitor updatedVisitor = Visitor(
                id: int.parse(searched_id.toString()),
                name: _guestNameController?.text,
                mobile: widget.mobile,
                visitor_image: "");

            await _updateVisitor(updatedVisitor);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnitSelectionView(
                widget.searchedVisitor,
                visitor: state.visitor,
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
                visitorNumber: _visitorNumberController?.text.isNotEmpty == true
                    ? "V${_visitorNumberController!.text}"
                    : (_visitorNumberController?.text.isEmpty == true
                        ? null
                        : _visitorNumberController?.text),
              ),
            ),
          );

          setState(() => _isSubmitting = false);
        } else if (state is VIENavigateToCameraState) {
          // Ensure camera state navigation is handled correctly
          final imageFile = await _captureImageFromCamera(context);

          if (imageFile != null) {
            // Dispatch the camera button pressed event
            _bloc.add(VIECameraButtonPressedEvent(
              purposeCategory: state.purposeCategory,
              imageFile: imageFile,
              visitor: state.visitor,
              operation: state.operation,
            ));
          } else {
            _showErrorSnackBar("Camera capture was canceled.");
          }
        }
      },
      builder: (context, state) {
        if (state is VisitorInEntryLoadingState) {
          return const LoaderView();
        }

        return MyScrollView(
          isScrollable: true,
          pageTitle: 'Purpose Entry - ${effectivePurpose.categoryName}',
          pageBody: _buildPurposeForm(effectivePurpose),
          floatingActionButton: CustomLargeBtn(
            onPressed: _handleSubmit,
            isText: !_isSubmitting,
            text: 'Next',
            widgetChild: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurposeForm(PurposeCategory1 purpose) {
    switch (purpose.categoryName) {
      case 'CABS':
        return _buildCabsForm();
      case 'DELIVERY':
        return _buildDeliveryForm(purpose);
      case 'GUEST':
        return _buildGuestForm();

      case 'VENDOR':
        return _buildVendorForm(purpose);
      default:
        return const Center(child: Text('Unknown Purpose'));
    }
  }

  Widget _buildCabsForm() {
    return Column(
      children: [
        CustomForm.textField(
          "Cab Driver Name",
          hintText: 'Enter Name',
          textController: _guestNameController,
          textCapitalization: TextCapitalization.words,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('guestName')),
        ),
        CustomForm.textField(
          "Cab Number",
          hintText: 'MH 12 AB 1234',
          textController: _carNumberController,
          length: 10,
          textCapitalization: TextCapitalization.characters,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('cabnumber')),
        ),
      ],
    );
  }

  Widget _buildDeliveryForm(PurposeCategory1 purpose) {
    final subCategories = purpose.subCategories;
    if (subCategories == null || subCategories.isEmpty) {
      return const Center(child: Text("No delivery companies available."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: CustomForm.textField(
            "Delivery Person Name",
            hintText: 'Enter delivery person name',
            textController: _guestNameController,
            textCapitalization: TextCapitalization.words,
            titleColor: Theme.of(context).colorScheme.onSurface,
            hintColor: Theme.of(context).colorScheme.onPrimary,
            suffixIcon: _buildMicButton(() => _handleMicPress('guestName')),
          ),
        ),

        // Company Selection Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Select Delivery Company',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final subCategory = subCategories[index];
              final isSelected = index == selectedCompanyIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCompanyIndex = index;
                    selectedSubCategoryId =
                        subCategory.subCategoryId?.toString();
                    log("Selected Index: $index");
                    log("Selected SubCategoryId: $selectedSubCategoryId");
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFEBE6) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xffC08261)
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xffC08261).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.contain,
                                    imageUrl: subCategory?.image ?? '',
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),

                              // Company Name
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  subCategory?.subCategoryName ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    // fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xffC08261)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Selection Indicator
                      if (isSelected)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xffC08261),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVendorForm(PurposeCategory1 purpose) {
    final subCategories = purpose.subCategories;

    if (subCategories == null || subCategories.isEmpty) {
      return const Center(child: Text("No vendor categories available."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: CustomForm.textField(
            "Vendor Name",
            hintText: 'Enter vendor name',
            textController: _guestNameController,
            textCapitalization: TextCapitalization.words,
            titleColor: Theme.of(context).colorScheme.onSurface,
            hintColor: Theme.of(context).colorScheme.onPrimary,
            suffixIcon: _buildMicButton(() => _handleMicPress('guestName')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Select Vendor Category',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(0),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
            ),
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final subCategory = subCategories[index];
              final isSelected = index == selectedCompanyIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCompanyIndex = index;
                    selectedSubCategoryId =
                        subCategory.subCategoryId.toString();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFEBE6) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xffC08261)
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xffC08261).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.contain,
                                    imageUrl: subCategory.image ?? '',
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                      Icons.business,
                                      color: Color(0xffC08261),
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  subCategory.subCategoryName ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xffC08261)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xffC08261),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGuestForm() {
    return Column(
      children: [
        CustomForm.textField(
          "Guest Name",
          hintText: 'Enter Name',
          textCapitalization: TextCapitalization.words,
          textController: _guestNameController,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('guestName')),
        ),
        // if (_visitorAddress == true)
        CustomForm.textField(
          "Coming From",
          hintText: 'Enter Coming From',
          textCapitalization: TextCapitalization.words,
          textController: _guestComingFromController,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('guestComingFrom')),
        ),
        if (_visitorCardNumber == true)
          CustomForm.textField(
            "Enter your ID",
            hintText: 'Request from Security',
            keyboardType: TextInputType.number,
            length: 4,
            textController: _visitorNumberController,
            titleColor: Theme.of(context).colorScheme.onSurface,
            hintColor: Theme.of(context).colorScheme.onPrimary,
            validator: _validateVisitorId,
            prefixIcon: _buildVisitorIdPrefix(),
          ),
        _buildGuestCountField(),
        const SizedBox(height: 150),
      ],
    );
  }

  Widget _buildMicButton(Future<void> Function() onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: CircleAvatar(
        backgroundColor: const Color(0xffFFEBE6),
        radius: 20,
        child: Icon(
          Ionicons.mic_outline,
          size: 22,
          color: Colors.black,
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
      child: const Center(child: Text("V")),
    );
  }

  Widget _buildGuestCountField() {
    return CustomForm.textField(
      "Guest Count",
      textController: _guestCountController,
      hintText: 'Guest Count',
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
              color: Colors.red,
              size: 32,
            ),
          ),
          IconButton(
            onPressed: _incrementGuestCount,
            icon: const Icon(
              Ionicons.add_circle_outline,
              size: 32,
              color: Colors.green,
            ),
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

  void dispose() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('visitor_coming_from');
    });

    _guestNameController?.dispose();
    _guestComingFromController?.dispose();
    _guestCountController?.dispose();
    _visitorNumberController?.dispose();
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 3,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => selectImage(index),
          child: Container(
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: selectedUserInput == index
                  ? Color(0xffFFEBE6)
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
                    style: TextStyle(
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
      duration: Duration(milliseconds: 1000),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              recognizedText,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) => Transform.scale(
                scale: _animation.value,
                child: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 50,
                    color: Colors.red,
                  ),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_hasRecognizedText) // Only show retry when we have recognized text
                  ElevatedButton.icon(
                    onPressed: _retryListening,
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ElevatedButton(
                  onPressed: () {
                    _stopListening();
                    if (_hasRecognizedText) {
                      Navigator.of(context).pop(recognizedText);
                    } else {
                      Navigator.of(context).pop(null);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _hasRecognizedText ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_hasRecognizedText ? 'Done' : 'Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CameraPreviewScreen extends StatefulWidget {
  final CameraController cameraController;

  CameraPreviewScreen({
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(this); // Add observer for lifecycle changes
    _currentCamera = widget.cameraController.description;
    _cameraController = widget.cameraController;
    _lockCameraToPortrait(); // Lock camera to portrait mode
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Prevent updating the camera orientation dynamically
  }

  Future<void> _lockCameraToPortrait() async {
    // Always lock the camera orientation to portraitUp
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
        enableAudio: false, // Disable audio if not needed
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Take Photo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_capturedImage == null)
            _cameraController.value.isInitialized
                ? ClipRRect(
                    child: Transform.scale(
                      scale: 1.0,
                      child: AspectRatio(
                        aspectRatio: _cameraController.value.aspectRatio,
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: FileImage(File(_capturedImage!.path)),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // Camera controls overlay
          if (_capturedImage == null)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          if (_capturedImage == null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildControlButton(
                      onPressed: _switchCamera,
                      icon: Icons.flip_camera_ios_rounded,
                      size: 30,
                    ),
                    GestureDetector(
                      onTap: () async {
                        try {
                          final image = await _cameraController.takePicture();
                          setState(() => _capturedImage = image);
                        } catch (e) {
                          print('Error capturing image: $e');
                        }
                      },
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.white24,
                        ),
                        child: Center(
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 30), // Balance the layout
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    onPressed: () => setState(() => _capturedImage = null),
                    icon: Icons.close,
                    label: 'Retake',
                    color: Colors.red,
                  ),
                  _buildActionButton(
                    onPressed: () => Navigator.pop(context, _capturedImage),
                    icon: Icons.check,
                    label: 'Use Photo',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    double size = 24,
  }) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black26,
        border: Border.all(color: Colors.white54, width: 1),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: size),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
