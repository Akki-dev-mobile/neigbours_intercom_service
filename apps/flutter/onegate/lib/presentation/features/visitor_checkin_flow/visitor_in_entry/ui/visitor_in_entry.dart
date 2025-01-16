// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/camera_provider.dart';
import 'package:flutter_onegate/purpose_mapper.dart';
import 'package:ionicons/ionicons.dart';
import 'package:onegate_client/onegate_client.dart';
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
  late final TextEditingController _guestNameController;
  late final TextEditingController _guestComingFromController;
  late final TextEditingController _guestCountController;
  late final TextEditingController _visitorNumberController;
  int selectedCompanyIndex = -1; // To track the selected company index

  bool _isSubmitting = false;
  int _guestCount = 1;
  bool? _visitorCardNumber = false;
  List<PurposeCategory1> _globalSelectedPurposes = [];
  final remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeBloc();
    _loadInitialData();
  }

  void _initializeControllers() {
    _guestNameController =
        TextEditingController(text: widget.searchedVisitor?.name);
    _guestComingFromController = TextEditingController();
    _guestCountController = TextEditingController(text: '1');
    _visitorNumberController = TextEditingController();
  }

  void _initializeBloc() {
    final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1,
      DioSingleton.instance2,
      DioSingleton.instance3,
    );

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

  final List<Map<String, String>> deliveryCompanies = [
    {
      'name': 'Amazon',
      'image':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSUk2zBfHzeV5yxsgE4tRO6Z2q5SozMWph8Og&s',
    },
    {
      'name': 'Flipkart',
      'image':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRcSx1XIyVOaGpvl6bEff5hZCuQze21m_Ph3A&s',
    },
    {
      'name': 'Zomato',
      'image':
          'https://content.jdmagicbox.com/v2/comp/mumbai/u1/022pxx22.xx22.170704134830.t7u1/catalogue/zomato-com-mumbai-corporate-companies-1fm7z2kn6v.jpg',
    },
    {
      'name': 'Swiggy',
      'image':
          'https://content.jdmagicbox.com/comp/mumbai/z1/022pxx22.xx22.150803125128.z7z1/catalogue/swiggy-com-branch-office-andheri-east-mumbai-online-websites-for-food-delivery-aijodveedn.jpg',
    },
    {
      'name': 'Dunzo',
      'image':
          'https://mir-s3-cdn-cf.behance.net/project_modules/1400/c79cc971959541.5bd75efd34d39.jpg',
    },
    {
      'name': 'BigBasket',
      'image':
          'https://cdn-images-1.medium.com/max/1200/1*kqElrV8y9kt64NDnfwqf6g.png',
    },
    {
      'name': 'Delhivery',
      'image':
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS2CQIMiyn44Rj9rbUflyH69dj0MaObVOeQPw&s',
    },
    {
      'name': 'Blue Dart',
      'image':
          'https://media.licdn.com/dms/image/v2/C4D0BAQGjOwzlSzSwCQ/company-logo_200_200/company-logo_200_200/0/1631329681950?e=2147483647&v=beta&t=oyASYPcfvBB1Iv3p0q3qS0TPae-pkg3oba7DBKXUr5U',
    },
    {
      'name': 'FedEx',
      'image':
          'https://content.jdmagicbox.com/v2/comp/bangalore/s1/080pxx80.xx80.231101201423.u9s1/catalogue/fedex-ship-site-bwc-international-kammanahalli-bangalore-international-courier-services-uguu63fg2i.jpg',
    },
  ];

  Future<String?> _handleMicPress(String field) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const ListeningDialog(),
    );

    if (result != null) {
      setState(() {
        switch (field) {
          case 'guestName':
            _guestNameController.text = result;
            break;
          case 'guestComingFrom':
            _guestComingFromController.text = result;
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
        _guestCountController.text = _guestCount.toString();
      });
    }
  }

  void _decrementGuestCount() {
    if (_guestCount > 1) {
      setState(() {
        _guestCount--;
        _guestCountController.text = _guestCount.toString();
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
        final localImage = File(
            '${appDocDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await File(image.path).copy(localImage.path);
        return localImage;
      } else {
        return null; // No image captured
      }
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    } finally {
      await cameraController?.dispose();
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);
    if (selectedCompanyIndex == -1) {
      _showErrorSnackBar("Please select a delivery company.");
    } else {
      final selectedCompany = deliveryCompanies[selectedCompanyIndex]['name']!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delivery Company Selected: $selectedCompany"),
          backgroundColor: Colors.green,
        ),
      );
    }

    try {
      _bloc.add(VIEGuestFormSubmitButtonPressedEvent(
        searchedVisitor: widget.searchedVisitor,
        guestName: _guestNameController.text,
        guestComingFrom: _guestComingFromController.text,
        guestCount: _guestCount,
        purposeCategory: widget.selectedValue!,
        mobile: widget.mobile,
      ));

      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      _showErrorSnackBar('An error occurred: ${e.toString()}');
    } finally {
      // Reset submission state
      setState(() => _isSubmitting = false);
    }
  }

  bool _validateForm() {
    if (_guestNameController.text.isEmpty) {
      _showErrorSnackBar('Please enter guest name');
      return false;
    }
    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
                name: _guestNameController.text,
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
                guestname: _guestNameController.text,
                mobileNumber: widget.mobile,
                purposeCategory: state.purposeCategory,
                comingFrom: _guestComingFromController.text,
                guestCount: _guestCount,
                visitorNumber: _visitorNumberController.text.isNotEmpty
                    ? "V${_visitorNumberController.text}"
                    : _visitorNumberController.text,
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
          pageTitle:
              'Purpose Entry - ${effectivePurpose.categoryName}',
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
        return _buildDeliveryForm();
      case 'GUEST':
        return _buildGuestForm();
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
          textCapitalization: TextCapitalization.words,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('cabDriverName')),
        ),
        CustomForm.textField(
          "Cab Number",
          hintText: 'MH 12 AB 1234',
          textCapitalization: TextCapitalization.characters,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('cabNumber')),
        ),
      ],
    );
  }

  Widget _buildDeliveryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery Person Name Field
        CustomForm.textField(
          "Delivery Person Name",
          hintText: 'Enter Name',
          textController: _guestNameController,
          textCapitalization: TextCapitalization.words,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          suffixIcon: _buildMicButton(() => _handleMicPress('deliveryName')),
        ),
        const SizedBox(height: 16),

        Text(
          'Select Delivery Company',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // Number of columns
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
          ),
          itemCount: deliveryCompanies.length,
          itemBuilder: (context, index) {
            final company = deliveryCompanies[index];
            final isSelected = index == selectedCompanyIndex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedCompanyIndex = index;
                });
              },
              child: Stack(
                children: [
                  Container(
                    height: 250,
                    width: 200,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0x10C08261)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xffC08261)
                            : Colors.grey,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child:  CachedNetworkImage(
                              maxHeightDiskCache: 90,
                              maxWidthDiskCache: 90,
                              height: 60,
                              width: 60,
                              fit: BoxFit.cover,
                              imageUrl: company['image']!,
                              placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(
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
                              company['name']!,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xffC08261)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
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
        const SizedBox(height: 16),
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

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestComingFromController.dispose();
    _guestCountController.dispose();
    _visitorNumberController.dispose();
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

// String? mobile;
  CameraPreviewScreen({
    Key? key,
    required this.cameraController,
    // this.mobile
  }) : super(key: key);

  @override
  _CameraPreviewScreenState createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  late CameraController _cameraController;
  late CameraDescription _currentCamera;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _currentCamera = widget.cameraController.description;
    _cameraController = widget.cameraController;
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
      );

      await newController.initialize();

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
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          if (_capturedImage == null)
            _cameraController.value.isInitialized
                ? Center(
                    child: CameraPreview(
                      _cameraController,
                    ),
                  )
                : const Center(child: CircularProgressIndicator())
          else
            Center(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain,
              ),
            ),
          if (_capturedImage == null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Switch camera button
                  FloatingActionButton(
                    heroTag: 'switchCamera',
                    onPressed: _switchCamera,
                    child: const Icon(Icons.switch_camera),
                  ),
                  // Capture button
                  FloatingActionButton(
                    heroTag: 'captureImage',
                    onPressed: () async {
                      try {
                        final XFile image =
                            await _cameraController.takePicture();
                        setState(() {
                          _capturedImage = image;
                        });
                      } catch (e) {
                        print('Error capturing image: $e');
                      }
                    },
                    child: const Icon(Icons.camera),
                  ),
                ],
              ),
            )
          else
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cross icon for Retake
                  FloatingActionButton(
                    heroTag: 'retake',
                    onPressed: () {
                      setState(() {
                        _capturedImage = null; // Retake the picture
                      });
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                    ),
                  ),
                  // Tick icon for Go Ahead
                  FloatingActionButton(
                    heroTag: 'goAhead',
                    onPressed: () {
                      Navigator.pop(
                          context, _capturedImage); // Proceed with the image
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}
