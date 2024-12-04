// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
// import 'package:cached_network_image/cached_networ k_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/app_intro/ui/keyclock_login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart';

import '../../units_selection/ui/unit_selection_view.dart';
import '../bloc/visitor_in_entry_bloc.dart';

class VisitorsInEntry extends StatefulWidget {
  final PurposeCategory selectedValue;
  final Visitor? searchedVisitor;
  final String mobile;
  final int companyId = GlobalUser.getUserId() ?? 55275;
  VisitorsInEntry(
      {Key? key,
      required this.selectedValue,
      this.searchedVisitor,
      required this.mobile})
      : super(key: key);

  @override
  State<VisitorsInEntry> createState() => _VisitorsInEntryState();
}

class _VisitorsInEntryState extends State<VisitorsInEntry> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _speechTextControllerId = '';
  late TextEditingController _guestCountController;
  final VisitorInEntryBloc visitorInEntryBloc = VisitorInEntryBloc(
      VisitorUsecase(VisitorRepoImpl(RemoteDataSource(DioSingleton.instance1,
          DioSingleton.instance2, DioSingleton.instance3))),
      VisitorLogUsecase(VisitorLogRepositoryImpl(RemoteDataSource(
          DioSingleton.instance1,
          DioSingleton.instance2,
          DioSingleton.instance3))));

  int _guestCount = 1;
  TextEditingController guestComingFrom = TextEditingController();
  TextEditingController guestName = TextEditingController();
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _guestCountController = TextEditingController(text: _guestCount.toString());
    if (widget.searchedVisitor != null) {
      //_lastWords = widget.searchedVisitor!.name;
      guestName.text = widget.searchedVisitor!.name;
    }
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening(String textControllerId) async {
    _speechTextControllerId = textControllerId;
    await _speechToText.listen(
      onResult: _onSpeechResult,
    );
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      switch (_speechTextControllerId) {
        case 'guestName':
          guestName.text = result.recognizedWords;
          break;
        case 'guestComingFrom':
          guestComingFrom.text = result.recognizedWords;
          break;
      }
    });
  }

  void _incrementGuestCount() {
    setState(() {
      _guestCount++;
      _guestCountController.text = _guestCount.toString();
    });
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
      visitorUsecase.uploadImage(localImage, widget.mobile, widget.companyId);

      return localImage;
    } catch (e) {
      print('Error capturing and saving image from camera: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  visitor: state.visitor,
                  comingFrom: guestComingFrom.text,
                  guestCount: _guestCount,
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
          if (_isInitialLoad && state is VisitorInEntryLoadingState) {
            return LoaderView();
          }
          _isInitialLoad = false; // Set to false after initial load

          return MyScrollView(
            backButtonPressed: () {
              Navigator.pop(context);
            },
            isScrollable: true,
            pageTitle: '${widget.selectedValue.purpose_category_name} Entry',
            pageBody: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.selectedValue.purpose_category_name == 'CABS')
                  Column(
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
                  ),
                if (widget.selectedValue.purpose_category_name == 'DELIVERY')
                  Column(
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
                  ),
                if (widget.selectedValue.purpose_category_name == 'GUEST')
                  Column(
                    children: [
                      CustomForm.textField(
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        "Guest Name",
                        hintText: 'Enter Name',
                        textCapitalization: TextCapitalization.words,
                        textController: guestName,
                        suffixIcon: IconButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (context) => ListeningDialog());
                            _speechToText.isNotListening
                                ? _startListening('guestName')
                                : _stopListening();
                          },
                          icon: CircleAvatar(
                            backgroundColor:
                                _speechTextControllerId == 'guestName' &&
                                        _speechToText.isListening
                                    ? Color(0xffCAF1D1)
                                    : Color(0xffFFEBE6),
                            radius: 20,
                            child: Icon(
                              size: 22,
                              Ionicons.mic_outline,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      CustomForm.textField(
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        "Coming From",
                        hintText: 'Enter Coming From',
                        textCapitalization: TextCapitalization.characters,
                        textController: guestComingFrom,
                        suffixIcon: IconButton(
                          onPressed: () {
                            _speechToText.isNotListening
                                ? _startListening('guestComingFrom')
                                : _stopListening();
                          },
                          icon: CircleAvatar(
                            backgroundColor:
                                _speechTextControllerId == 'guestComingFrom' &&
                                        _speechToText.isListening
                                    ? Color(0xffCAF1D1)
                                    : Color(0xffFFEBE6),
                            radius: 20,
                            child: Icon(
                              size: 22,
                              Ionicons.mic_outline,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      CustomForm.textField(
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        "Enter your ID",
                        hintText: 'Request from Security',
                        keyboardType: TextInputType.text,
                        length: 4,
                      ),
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
                  ),
                if (widget.selectedValue.purpose_category_name == 'STAFF')
                  Column(
                    children: [
                      CustomForm.textField(
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        "Staff Name",
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
                          'Select Staff Category',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      SelectTypeWidget(),
                    ],
                  ),
                if (widget.selectedValue.purpose_category_name == 'VENDOR')
                  Column(
                    children: [
                      CustomForm.textField(
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        "Vendor Name",
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
                          'Select Vendor Category',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      SelectTypeWidget(),
                    ],
                  ),
              ],
            ),
            floatingActionButton: CustomLargeBtn(
              onPressed: () {
                _captureImageFromCamera();

                // visitorInEntryBloc.add(VIEGuestFormSubmitButtonPressedEvent(
                //     searchedVisitor: widget.searchedVisitor,
                //     guestName: guestName.text,
                //     guestComingFrom: guestComingFrom.text,
                //     guestCount: _guestCount,
                //     purposeCategory: widget.selectedValue,
                //     mobile: widget.mobile));
              },
              text: 'Next',
            ),
          );
        });
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
                // ClipRRect(
                //   borderRadius: BorderRadius.circular(15),
                //   child: CachedNetworkImage(
                //     maxHeightDiskCache: 80,
                //     maxWidthDiskCache: 80,
                //     height: 60,
                //     width: 60,
                //     filterQuality: FilterQuality.high,
                //     fit: BoxFit.contain,
                //     imageUrl: imagePaths[index],
                //     placeholder: (context, url) =>
                //         const CircularProgressIndicator(),
                //     errorWidget: (context, url, error) => const Icon(
                //       Icons.error,
                //       color: Colors.red,
                //     ),
                //     fadeOutDuration: const Duration(seconds: 1),
                //     fadeInDuration: const Duration(seconds: 3),
                //   ),
                // ),
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

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();

    // Animation for pulsing mic icon
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startListening(
        'guestComingFrom'); // Automatically start listening when dialog opens
  }

  // Toggle between listening and not listening
  void _toggleListening(String contextLabel) {
    if (!_isListening) {
      _startListening(contextLabel);
    } else {
      _stopListening();
    }
  }

  // Start listening
  Future<void> _startListening(String contextLabel) async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => print('Error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          setState(() => recognizedText = result.recognizedWords);
        },
      );
    }
  }

  // Stop listening
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
                  onPressed: () => _toggleListening('guestComingFrom'),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _stopListening(); // Ensure it stops listening on exit
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
