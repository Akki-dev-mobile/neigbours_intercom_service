// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/id_input_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:page_transition/page_transition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../units_selection/ui/unit_selection_view.dart';
import '../bloc/visitor_in_entry_bloc.dart';

class VisitorsInEntry extends StatefulWidget {
  final PurposeCategory selectedValue;
  Visitor? searchedVisitor;
  final String mobile;
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
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
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

  @override
  void initState() {
    super.initState();
    _guestCountController = TextEditingController(text: _guestCount.toString());
    if (widget.searchedVisitor != null) {
      _lastWords = widget.searchedVisitor!.name;
      guestName.text = widget.searchedVisitor!.name;
    }
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
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

  PickedFile? _imageFile;

  Future<void> _captureImageFromCamera() async {
    final picker = ImagePicker();

    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _imageFile = PickedFile(image.path);
      });

      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => UnitSelectionView(),
      //   ),
      // );
    } catch (e) {
      print('Error capturing image from camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VisitorInEntryBloc, VisitorInEntryState>(
      bloc: visitorInEntryBloc,
      listenWhen: (previous, current) => current is VisitorInEntryActionState,
      buildWhen: (previous, current) => current is! VisitorInEntryActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case VIENavigateToUnitSelectionState:
            final unitSelectionState = state as VIENavigateToUnitSelectionState;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitSelectionView(
                  purposeCategory: unitSelectionState.purposeCategory,
                  visitor: unitSelectionState.visitor,
                  comingFrom: guestComingFrom.text,
                  guestCount: _guestCount,
                ),
              ),
            );
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case VisitorInEntryLoadingState:
            return Container(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          default:
            return MyScrollView(
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
                          titleColor:
                              Theme.of(context).colorScheme.onBackground,
                          hintColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        CustomForm.textField(
                          titleColor:
                              Theme.of(context).colorScheme.onBackground,
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
                          titleColor:
                              Theme.of(context).colorScheme.onBackground,
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
                        Text(_lastWords),
                        CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Guest Name",
                            hintText: 'Enter Name',
                            textCapitalization: TextCapitalization.words,
                            textController: guestName
                            // suffixIcon: IconButton(
                            //   onPressed: () {
                            //     _speechToText.isNotListening
                            //         ? _startListening()
                            //         : _stopListening();
                            //   },
                            //   icon: CircleAvatar(
                            //     backgroundColor: _speechToText.isNotListening
                            //         ? Color(0xffFFEBE6)
                            //         : Color(0xffCAF1D1),
                            //     radius: 20,
                            //     child: Icon(
                            //       size: 22,
                            //       Ionicons.mic_outline,
                            //       color: Colors.black,
                            //     ),
                            //   ),
                            // ),
                            ),
                        CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Coming From",
                            hintText: 'Enter Coming From',
                            textCapitalization: TextCapitalization.characters,
                            textController: guestComingFrom
                            // suffixIcon: IconButton(
                            //   onPressed: () {},
                            //   icon: CircleAvatar(
                            //     backgroundColor: Color(0xffFFEBE6),
                            //     radius: 20,
                            //     child: Icon(
                            //       size: 22,
                            //       Ionicons.mic_outline,
                            //       color: Colors.black,
                            //     ),
                            //   ),
                            // ),
                            ),
                        CustomForm.textField(
                          "Guest Count",
                          textController: _guestCountController,
                          hintText: 'Guest Count',
                          keyboardType: TextInputType.number,
                          titleColor:
                              Theme.of(context).colorScheme.onBackground,
                          hintColor: Theme.of(context).colorScheme.onPrimary,
                          length: 2,
                          onChanged: (value) {
                            setState(() {
                              _guestCount = int.tryParse(value) ?? 1;
                            });
                          },
                          suffixIcon: ButtonBar(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _incrementGuestCount,
                                icon: Icon(
                                  Ionicons.add_circle_outline,
                                  size: 32,
                                  color: Colors.green,
                                ),
                              ),
                              IconButton(
                                onPressed: _decrementGuestCount,
                                icon: Icon(
                                  Ionicons.remove_circle_outline,
                                  color: Colors.red,
                                  size: 32,
                                ),
                              ),
                              
                            ],
                          ),
                        ),
                        CustomForm.textField(
                                titleColor:
                                    Theme.of(context).colorScheme.onBackground,
                                hintColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                "Enter your ID",
                                hintText: 'Request from Security',
                                keyboardType: TextInputType.text,
                                length: 4,
                              )
                      ],
                    ),
                  if (widget.selectedValue.purpose_category_name == 'STAFF')
                    Column(
                      children: [
                        CustomForm.textField(
                          titleColor:
                              Theme.of(context).colorScheme.onBackground,
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
                          titleColor:
                              Theme.of(context).colorScheme.onBackground,
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
                  visitorInEntryBloc.add(VIEGuestFormSubmitButtonPressedEvent(
                      searchedVisitor: widget.searchedVisitor,
                      guestName: guestName.text,
                      guestComingFrom: guestComingFrom.text,
                      guestCount: _guestCount,
                      purposeCategory: widget.selectedValue,
                      mobile: widget.mobile));
                  //_captureImageFromCamera();
                },
                text: 'Next',
              ),
            );
        }
      },
    );
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: CachedNetworkImage(
                    maxHeightDiskCache: 80,
                    maxWidthDiskCache: 80,
                    height: 60,
                    width: 60,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.contain,
                    imageUrl: imagePaths[index],
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.error,
                      color: Colors.red,
                    ),
                    fadeOutDuration: const Duration(seconds: 1),
                    fadeInDuration: const Duration(seconds: 3),
                  ),
                ),
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
