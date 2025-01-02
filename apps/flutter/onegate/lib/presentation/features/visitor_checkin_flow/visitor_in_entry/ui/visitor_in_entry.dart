// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/purpose_mapper.dart';
import 'package:flutter_onegate/utils/shared_pref.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart';

import '../../units_selection/ui/unit_selection_view.dart';
import '../bloc/visitor_in_entry_bloc.dart';

class VisitorsInEntry extends StatefulWidget {
  final PurposeCategory? selectedValue;
  final VisitorMapper? searchedVisitor;
  final String mobile;

  // final int companyId = GlobalUser.getUserId() ?? 55275;

  VisitorsInEntry(
      {Key? key,
      this.selectedValue,
      this.searchedVisitor,
      required this.mobile})
      : super(key: key);

  @override
  State<VisitorsInEntry> createState() => _VisitorsInEntryState();
}

class _VisitorsInEntryState extends State<VisitorsInEntry> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  final PreferenceUtils preferenceUtils = GetIt.I<PreferenceUtils>();
  String _speechTextControllerId = '';
  late TextEditingController _guestCountController;
  final VisitorInEntryBloc visitorInEntryBloc = VisitorInEntryBloc(
      VisitorUsecase(VisitorRepoImpl(RemoteDataSource(DioSingleton.instance1,
          DioSingleton.instance2, DioSingleton.instance3))),
      VisitorLogUsecase(VisitorLogRepositoryImpl(RemoteDataSource(
          DioSingleton.instance1,
          DioSingleton.instance2,
          DioSingleton.instance3))));
  final GateStorage gateStorage = GateStorage();
  bool isText = true;

  int _guestCount = 1;
  TextEditingController guestComingFrom = TextEditingController();
  TextEditingController guestName = TextEditingController();
  TextEditingController visitorNumber = TextEditingController();
  bool _isInitialLoad = true;
  int? companyId;

  @override
  void initState() {
    super.initState();
    _guestCountController = TextEditingController(text: _guestCount.toString());
    if (widget.searchedVisitor != null) {
      guestName.text = widget.searchedVisitor!.name;
    }
    _initSpeech();
    _fetchCompanyId();
    _loadSelectedPurposesToGlobal();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  Future<void> _fetchCompanyId() async {
    companyId = await gateStorage.getSocietyId();
    setState(() {});
  }

  // void _startListening(String textControllerId) async {
  //   _speechTextControllerId = textControllerId;
  //   await _speechToText.listen(
  //     onResult: _onSpeechResult,
  //   );
  //   setState(() {});
  // }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  // void _onSpeechResult(SpeechRecognitionResult result) {
  //   setState(() {
  //     switch (_speechTextControllerId) {
  //       case 'guestName':
  //         guestName.text = result.recognizedWords;
  //         break;
  //       case 'guestComingFrom':
  //         guestComingFrom.text = result.recognizedWords;
  //         break;
  //     }
  //   });
  // }
  void _handleMicPress(String fieldId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ListeningDialog(),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        switch (fieldId) {
          case 'guestName':
            guestName.text = result;
            break;
          case 'guestComingFrom':
            guestComingFrom.text = result;
            break;
          case 'visitorNumber':
            visitorNumber.text = result;
            break;
        }
      });
    }
  }

  void _incrementGuestCount() {
    setState(() {
      _guestCount++;
      _guestCountController.text = _guestCount.toString();
    });
  }

  List<PurposeCategory> globalSelectedPurposes = [];

  Future<void> _loadSelectedPurposesToGlobal() async {
    try {
      final roh = await SharedPreferences.getInstance();
      final jsonString = roh.getString('selected_purposes');
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          globalSelectedPurposes = jsonList
              .map((json) => PurposeCategoryMapper.fromJson(json))
              .toList();
        });
        print("Global selected purposes loaded: $globalSelectedPurposes");
      }
    } catch (e) {
      print("Failed to load selected purposes into global variable: $e");
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

  //PickedFile? _imageFile;

  // ignore: body_might_complete_normally_nullable
  Future<File?> _captureImageFromCamera() async {
    // final picker = ImagePicker();
    // try {
    //   final image = await picker.pickImage(
    //     source: ImageSource.camera,
    //   );
    //   return image;
    // } catch (e) {
    //   print('Error capturing image from camera: $e');
    // }
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25,
      );

      if (image == null) {
        // User canceled the capture
        return null;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = appDocDir.path;

      final File localImage =
          File('$appDocPath/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await localImage.writeAsBytes(await image.readAsBytes());

      final visitorUsecase = VisitorUsecase(VisitorRepoImpl(RemoteDataSource(
          DioSingleton.instance1,
          DioSingleton.instance2,
          DioSingleton.instance3)));
      visitorUsecase.uploadImage(localImage, widget.mobile, companyId!);

      return localImage;
    } catch (e) {
      print('Error capturing and saving image from camera: $e');
      return null;
    }
  }

  PurposeCategory? getEffectivePurposeCategory() {
    return widget.selectedValue ??
        (globalSelectedPurposes.isNotEmpty
            ? globalSelectedPurposes.first
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final effectivePurpose = getEffectivePurposeCategory();

    // Check if the purpose is null or not available
    if (effectivePurpose == null) {
      return Center(
        child: Text(
          "No purpose selected or available.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return BlocConsumer<VisitorInEntryBloc, VisitorInEntryState>(
        bloc: visitorInEntryBloc,
        listenWhen: (previous, current) => current is VisitorInEntryActionState,
        listener: (context, state) async {
          if (state is VIENavigateToUnitSelectionState) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitSelectionView(
                  visitorId: widget.searchedVisitor?.id,
                  guestname: guestName.text,
                  mobileNumber: widget.mobile,
                  purposeCategory: state.purposeCategory,
                  visitor: state.visitor as Visitor,
                  comingFrom: guestComingFrom.text,
                  guestCount: _guestCount,
                  visitorNumber: visitorNumber.text.isNotEmpty
                      ? "V${visitorNumber.text}"
                      : visitorNumber.text,
                  // visitorNumber: visitorNumber.text,
                ),
              ),
            );
          } else if (state is VIENavigateToCameraState) {
            final imageFile = await _captureImageFromCamera();
            if (imageFile != null) {
              visitorInEntryBloc.add(VIECameraButtonPressedEvent(
                purposeCategory: state.purposeCategory,
                imageFile: imageFile,
                visitor: state.visitor,
                operation: state.operation,
              ));
            }
          }
        },
        builder: (context, state) {
          // Loader display on initial state
          if (_isInitialLoad && state is VisitorInEntryLoadingState) {
            return LoaderView();
          }
          _isInitialLoad = false; // Disable loader after initial load

          return MyScrollView(
              backButtonPressed: () {
                Navigator.pop(context);
              },
              isScrollable: true,
              pageTitle:
                  'Purpose Entry - ${effectivePurpose.purpose_category_name}',
              pageBody: _buildPurposeForm(effectivePurpose),
              floatingActionButton: CustomLargeBtn(
                onPressed: () {
                  if (isText == true) {
                    if (guestName.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter guest name'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else if (preferenceUtils.getTooglevalue() == true &&
                        guestComingFrom.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Coming from is mandatory field'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      setState(() {
                        isText = false;
                      });
                      visitorInEntryBloc.add(
                          VIEGuestFormSubmitButtonPressedEvent(
                              searchedVisitor: widget.searchedVisitor,
                              guestName: guestName.text,
                              guestComingFrom: guestComingFrom.text,
                              guestCount: _guestCount,
                              purposeCategory: widget.selectedValue!,
                              mobile: widget.mobile ?? ""));
                    }
                  }
                },
                isText: isText,
                text: 'Next',
                widgetChild: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ));
        });
  }

  Widget _buildPurposeForm(PurposeCategory purpose) {
    if (purpose.purpose_category_name == 'CABS') {
      return _buildCabsForm();
    } else if (purpose.purpose_category_name == 'DELIVERY') {
      return _buildDeliveryForm();
    } else if (purpose.purpose_category_name == 'GUEST') {
      return _buildGuestForm();
    } else {
      return Center(
        child: Text('Unknown Purpose'),
      );
    }
  }

  Widget _buildCabsForm() {
    return Column(
      children: [
        CustomForm.textField(
          "Cab Driver Name",
          hintText: 'Enter Name',
          textCapitalization: TextCapitalization.words,
          suffixIcon: IconButton(
            onPressed: () {},
            icon: CircleAvatar(
              backgroundColor: Color(0xffFFEBE6),
              radius: 20,
              child: Icon(
                size: 22,
                Ionicons.mic_outline,
                color: Colors.black,
              ),
            ),
          ),
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
        ),
        CustomForm.textField(
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          "Cab Number",
          hintText: 'MH 12 AB 1234',
          textCapitalization: TextCapitalization.characters,
          suffixIcon: IconButton(
            onPressed: () {},
            icon: CircleAvatar(
              backgroundColor: Color(0xffFFEBE6),
              radius: 20,
              child: Icon(
                size: 22,
                Ionicons.mic_outline,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomForm.textField(
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          "Delivery Person Name",
          hintText: 'Enter Name',
          textCapitalization: TextCapitalization.words,
          suffixIcon: IconButton(
            onPressed: () {},
            icon: CircleAvatar(
              backgroundColor: Color(0xffFFEBE6),
              radius: 20,
              child: Icon(
                size: 22,
                Ionicons.mic_outline,
                color: Colors.black,
              ),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Select Delivery Company',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        SelectTypeWidget(),
      ],
    );
  }

  Widget _buildGuestForm() {
    return Column(
      children: [
        CustomForm.textField(
            titleColor: Theme.of(context).colorScheme.onSurface,
            hintColor: Theme.of(context).colorScheme.onPrimary,
            "Guest Name",
            hintText: 'Enter Name',
            textCapitalization: TextCapitalization.words,
            textController: guestName,
            suffixIcon: IconButton(
              onPressed: () => _handleMicPress('guestName'),
              icon: CircleAvatar(
                backgroundColor: Color(0xffFFEBE6),
                radius: 20,
                child: Icon(
                  size: 22,
                  Ionicons.mic_outline,
                  color: Colors.black,
                ),
              ),
            )),
        CustomForm.textField(
            titleColor: Theme.of(context).colorScheme.onSurface,
            hintColor: Theme.of(context).colorScheme.onPrimary,
            "Coming From",
            hintText: 'Enter Coming From',
            textCapitalization: TextCapitalization.words,
            textController: guestComingFrom,
            suffixIcon: IconButton(
              onPressed: () => _handleMicPress('guestComingFrom'),
              icon: CircleAvatar(
                backgroundColor: Color(0xffFFEBE6),
                radius: 20,
                child: Icon(
                  size: 22,
                  Ionicons.mic_outline,
                  color: Colors.black,
                ),
              ),
            )),
        // preferenceUtils.getTooglevalue() == true
        //     ?
        CustomForm.textField(
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your ID';
            }
            return null;
          },
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onPrimary,
          "Enter your ID",
          hintText: 'Request from Security',
          keyboardType: TextInputType.number,
          length: 4,
          textController: visitorNumber,
          prefixIcon: Container(
            width: 20,
            margin: EdgeInsets.only(
              left: 10,
              right: 10,
            ),
            decoration: BoxDecoration(
              color: Color(0xffFFEBE6),
              borderRadius: BorderRadius.circular(100),
            ),
            // radius: 16,
            child: Center(
              child: Text(
                "V",
              ),
            ),
          ),
        ),
        // : SizedBox(),
        CustomForm.textField(
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
            // mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _decrementGuestCount,
                icon: Icon(
                  Ionicons.remove_circle_outline,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              IconButton(
                onPressed: _incrementGuestCount,
                icon: Icon(
                  Ionicons.add_circle_outline,
                  size: 32,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 150),
      ],
    );
  }

  Widget? _buildVendorForm() {
    return null;

    //   Column(
    //   children: [
    //     CustomForm.textField(
    //       "Vendor Name", titleColor: null, hintColor: null, hintText: '',
    //     ),
    //     SelectTypeWidget(),
    //   ],
    // );
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
