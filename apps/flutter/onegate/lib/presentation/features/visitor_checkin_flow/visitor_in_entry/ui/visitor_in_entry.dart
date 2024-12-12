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
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../units_selection/ui/unit_selection_view.dart';
import '../bloc/visitor_in_entry_bloc.dart';

class VisitorsInEntry extends StatefulWidget {
  final PurposeCategory selectedValue;
  final Visitor? searchedVisitor;
  final String mobile;

  const VisitorsInEntry({
    Key? key,
    required this.selectedValue,
    this.searchedVisitor,
    required this.mobile,
  }) : super(key: key);

  @override
  State<VisitorsInEntry> createState() => _VisitorsInEntryState();
}

class _VisitorsInEntryState extends State<VisitorsInEntry> {
  final SpeechToText _speechToText = SpeechToText();
  final VisitorInEntryBloc visitorInEntryBloc = VisitorInEntryBloc(
    VisitorUsecase(VisitorRepoImpl(RemoteDataSource(
      DioSingleton.instance1,
      DioSingleton.instance2,
      DioSingleton.instance3,
    ))),
    VisitorLogUsecase(VisitorLogRepositoryImpl(RemoteDataSource(
      DioSingleton.instance1,
      DioSingleton.instance2,
      DioSingleton.instance3,
    ))),
  );

  final GateStorage gateStorage = GateStorage();
  late TextEditingController _guestCountController;
  late TextEditingController guestName;
  late TextEditingController guestComingFrom;

  int? companyId;
  int _guestCount = 1;
  bool _speechEnabled = false;
  String _speechTextControllerId = '';
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _guestCountController = TextEditingController(text: _guestCount.toString());
    guestName = TextEditingController(
        text: widget.searchedVisitor?.name ?? ""); // Prefill if available
    guestComingFrom = TextEditingController();

    _initSpeech();
    _fetchCompanyId();
  }

  Future<void> _fetchCompanyId() async {
    companyId = await gateStorage.getSocietyId();
    setState(() {});
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening(String textControllerId) async {
    _speechTextControllerId = textControllerId;
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      if (_speechTextControllerId == 'guestName') {
        guestName.text = result.recognizedWords;
      } else if (_speechTextControllerId == 'guestComingFrom') {
        guestComingFrom.text = result.recognizedWords;
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

  Future<File?> _captureImageFromCamera() async {
    final picker = ImagePicker();
    try {
      final image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 25);

      if (image == null) return null;

      final appDocDir = await getApplicationDocumentsDirectory();
      final localImagePath =
          '${appDocDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final localImage = File(localImagePath);
      await localImage.writeAsBytes(await image.readAsBytes());

      return localImage;
    } catch (e) {
      print('Error capturing and saving image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VisitorInEntryBloc, VisitorInEntryState>(
      bloc: visitorInEntryBloc,
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
            visitorInEntryBloc.add(
              VIECameraButtonPressedEvent(
                purposeCategory: state.purposeCategory,
                imageFile: imageFile,
                visitor: state.visitor,
                operation: state.operation,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        if (_isInitialLoad && state is VisitorInEntryLoadingState) {
          return LoaderView();
        }
        _isInitialLoad = false;

        return MyScrollView(
          pageTitle: '${widget.selectedValue.purpose_category_name} Entry',
          pageBody: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Additional UI as per your requirements
            ],
          ),
          floatingActionButton: CustomLargeBtn(
            onPressed: () {
              if (guestName.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter guest name')),
                );
              } else if (guestComingFrom.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Coming from is mandatory field')),
                );
              } else {
                visitorInEntryBloc.add(
                  VIEGuestFormSubmitButtonPressedEvent(
                    searchedVisitor: widget.searchedVisitor,
                    guestName: guestName.text,
                    guestComingFrom: guestComingFrom.text,
                    guestCount: _guestCount,
                    purposeCategory: widget.selectedValue,
                    mobile: widget.mobile,
                  ),
                );
              }
            },
            text: 'Next',
          ),
        );
      },
    );
  }
}
