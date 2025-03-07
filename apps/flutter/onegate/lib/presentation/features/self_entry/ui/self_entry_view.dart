// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:numpad_layout/numpad.dart';
import 'package:numpad_layout/widgets/numpad.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../../data/datasources/gate_storage.dart';
import '../../dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import '../../visitor_checkin_flow/units_selection/ui/unit_selection_view.dart';

class SelfEntryView extends StatefulWidget {
  const SelfEntryView({super.key});

  @override
  State<SelfEntryView> createState() => _SelfEntryViewState();
}

class _SelfEntryViewState extends State<SelfEntryView>
    with TickerProviderStateMixin {
  // Variables for current step and country code.
  int activeStep = 0;
  String code = "";
  String selectedCountryCodeSE = 'IN';

  // Create an instance of RemoteDataSource.
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  final GateStorage _gateStorage = GateStorage();

  // Text controllers.
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _locationFocusNode = FocusNode();
  final FocusNode _purposeFocusNode = FocusNode();
  final FocusNode _hostFocusNode = FocusNode();
  final _flutterKioskMode = FlutterKioskMode.instance();

  late Timer _timer = Timer(Duration.zero, () {});
  int _start = 10;
  PickedFile? _imageFile;

  late TabController _tabController;

  int? _visitorId;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  void _disableKioskMode() async {
    try {
      await _flutterKioskMode.stop();
    } catch (e) {
      print("Error stopping kiosk mode: $e");
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _mobileController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _purposeController.dispose();
    _hostController.dispose();
    _nameFocusNode.dispose();
    _locationFocusNode.dispose();
    _purposeFocusNode.dispose();
    _hostFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Starts a countdown timer.
  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  /// Sends an OTP for self-checkin.
  Future<void> selfCheckInOtp(String mobileNumber) async {
    try {
      final result =
          await _remoteDataSource.sendOtpForSelfCheckIn(mobileNumber);

      if (result['message'] == 'Visitor is already verified') {
        final visitorData = result['data'];
        final visitor = Visitor(
          id: visitorData['id'],
          name: visitorData['name'] ?? '',
          mobile: visitorData['mobile'] ?? '',
          visitor_image: visitorData['visitor_image'],
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnitSelectionView(
              null,
              visitor: visitor,
              guestname: visitor.name ?? '',
              mobileNumber: visitor.mobile ?? '',
              purposeCategory: globalSelectedPurposes.isNotEmpty &&
                      selectedImageIndex != null
                  ? globalSelectedPurposes[selectedImageIndex!]
                  : PurposeCategory1(
                      categoryId: 1, categoryName: "Default Category"),
              comingFrom: visitorData['coming_from'] ?? '',
              carNumber: null,
              guestCount: 1,
              isVerified: true,
            ),
          ),
        );
        return;
      }

      _tabController.animateTo(1);
      _start = 10; // Default timer value
      startTimer();
    } catch (e) {
      log('Error sending OTP: $e');
      myFluttertoast(
          msg: "Error sending OTP. Please try again.",
          backgroundColor: Colors.red);
    }
  }

  /// Verifies the self-checkin OTP.

  Future<void> verifySelfCheckin(String mobileNumber, String otp) async {
    try {
      final result = await _remoteDataSource.verifySelfCheckin(
        mobileNumber: mobileNumber,
        otp: otp,
      );
      log('OTP verification response: $result');

      log("Result message: ${result['message']}");
      log("Result data: ${result['data']}");

      if (result['data'] != null && result['data'] is Map<String, dynamic>) {
        final dynamic idValue = result['data']['id'];
        if (idValue is int) {
          _visitorId = idValue;
        } else if (idValue is String) {
          _visitorId = int.tryParse(idValue);
        }
        log("Visitor id set to: $_visitorId");
      }

      if (result['message'] == 'Visitor is already verified') {
        final prefs = await SharedPreferences.getInstance();

        final visitorId = prefs.getString('visitorId');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnitSelectionView(null,
                visitor: Visitor(
                  id: int.parse(visitorId ?? ""),
                  name: _nameController.text,
                  mobile: _mobileController.text,
                  visitor_image: _imageFile?.path,
                ),
                guestname: _nameController.text,
                mobileNumber: _mobileController.text,
                purposeCategory: getPurposeCategory1(null),
                comingFrom: _locationController.text,
                carNumber: null,
                guestCount: 1,
                isVerified: result['message'] == "Visitor is already verified"
                    ? true
                    : false),
          ),
        );
        return;
      }

      myFluttertoast(msg: "OTP verified successfully!");
      _tabController.animateTo(2);
    } catch (e) {
      log('Error during OTP verification: $e');
      myFluttertoast(
          msg: "OTP verification failed. Please try again.",
          backgroundColor: Colors.red);
    }
  }

  List<PurposeCategory1> globalSelectedPurposes = [];
  int? selectedImageIndex;

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  Future<void> loadPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPurposes = prefs.getString('selected_purposes');
      if (savedPurposes != null) {
        final decoded = jsonDecode(savedPurposes) as List;
        globalSelectedPurposes =
            decoded.map((e) => PurposeCategory1.fromJson(e)).toList();
      }
      log(globalSelectedPurposes.first.categoryName);
    } catch (e) {
      debugPrint("Failed to load purposes: $e");
    }
  }

  Widget _buildPurposeGrid(StateSetter setState, BuildContext context,
      {String? category}) {
    final filteredPurposes = category == null
        ? globalSelectedPurposes
        : globalSelectedPurposes
            .where((purpose) => purpose.categoryName == category)
            .toList();

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: filteredPurposes.length,
      itemBuilder: (context, index) {
        final purpose = filteredPurposes[index];

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedImageIndex = index; // Update selection
            });
          },
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                          purpose.categoryName,
                          style: TextStyle(
                            color: selectedImageIndex == index
                                ? const Color(0xffC08261)
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: selectedImageIndex == index
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
                    Icons.check_circle_outline,
                    color: Color(0xffC08261),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _regImage(String name, File? image) async {
    if (image == null) return;

    try {
      final uri = Uri.parse('http://192.168.1.9:8000/api/register-face/');
      final request = http.MultipartRequest('POST', uri)
        ..fields['name'] = name
        ..files.add(await http.MultipartFile.fromPath('files', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print(response.body);

      if (response.statusCode == 200) {
        var jsondata = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsondata["message"])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${response.body}')),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// Captures an image from the camera.
  /// After capturing the image, it immediately navigates to the UnitSelectionView,
  /// passing along the visitor id (if available) in the Visitor object.
  Future<void> _captureImageFromCamera() async {
    loadPurposes();
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null) return;
      setState(() {
        _imageFile = PickedFile(image.path);
      });
      print(_mobileController.text);
      _regImage(_mobileController.text, File(image.path));
      _remoteDataSource.createVisitor(Visitor(
        name: _nameController.text,
        mobile: _mobileController.text,
        visitor_image: _imageFile?.path,
      ));

      final prefs = await SharedPreferences.getInstance();

      final visitorId = prefs.getString('visitorId');
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allows for height adjustment
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height *
                    0.6, // 60% of screen height
                child: Container(
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
                    children: [
                      ListTile(
                        title: Text(
                          'Select Purpose of visit',
                          style:
                              Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        trailing: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 28,
                        ),
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: globalSelectedPurposes.isEmpty
                            ? _buildPurposeGrid(setState, context,
                                category: "GUEST")
                            : _buildPurposeGrid(setState, context),
                      ),
                      // Next Button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: CustomLargeBtn(
                          text: 'Next',
                          onPressed: () {
                            Visitor visitor = Visitor();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VisitorsInEntry(
                                  searchedVisitor: visitor,
                                  selectedValue: globalSelectedPurposes[
                                      selectedImageIndex ?? 0],
                                  mobile: _mobileController.text,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => UnitSelectionView(
      //       null,
      //       visitor: Visitor(
      //         id: int.parse(visitorId ?? ""),
      //         name: _nameController.text,
      //         mobile: _mobileController.text,
      //       ),
      //       guestname: _nameController.text,
      //       mobileNumber: _mobileController.text,
      //       purposeCategory: getPurposeCategory1(null),
      //       comingFrom: _locationController.text,
      //       carNumber: null,
      //       guestCount: 1,
      //     ),
      //   ),
      // );
    } catch (e) {
      log('Error capturing image from camera: $e');
    }
  }

  /// Converts a purpose category string (JSON or numeric ID) into a PurposeCategory1 instance.
  PurposeCategory1 getPurposeCategory1(String? categoryStr) {
    if (categoryStr != null && categoryStr.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonData = json.decode(categoryStr);
        return PurposeCategory1.fromJson(jsonData);
      } catch (e) {
        int catId = int.tryParse(categoryStr) ?? 1;
        return PurposeCategory1(
            categoryId: catId, categoryName: "Category $catId");
      }
    }
    return PurposeCategory1(categoryId: 1, categoryName: "Default Category");
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside.
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              backgroundColor: Colors.white,
              expandedHeight: MediaQuery.of(context).size.height * 0.3,
              title: RichText(
                text: TextSpan(
                  text: 'one',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                  children: <TextSpan>[
                    TextSpan(
                        text: 'gate', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: Icon(Symbols.qr_code, color: Colors.black),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: CarouselSlider(
                  items: [
                    SelfEntryAd(
                      bgImage:
                          'https://images.unsplash.com/photo-1631195092568-a1030d926fd3?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80',
                      title: 'onegate',
                      subTitle:
                          'Secure your home and manage visitors, connect with society gate and much more',
                    ),
                    SelfEntryAd(
                      bgImage:
                          'https://images.unsplash.com/photo-1496065187959-7f07b8353c55?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80',
                      title: 'oneapp',
                      subTitle: 'The ALL in One App',
                    ),
                    SelfEntryAd(
                      bgImage:
                          'https://images.unsplash.com/photo-1580041065738-e72023775cdc?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80',
                      title: 'onesociety',
                      subTitle:
                          'Experience the Ease of Community Management with onesociety',
                    ),
                  ],
                  options: CarouselOptions(
                    height: 400.0,
                    enlargeCenterPage: true,
                    autoPlay: true,
                    autoPlayCurve: Curves.fastOutSlowIn,
                    enableInfiniteScroll: true,
                    autoPlayAnimationDuration: Duration(milliseconds: 1000),
                    viewportFraction: 1,
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.0),
                    border: Border(
                        bottom: BorderSide(color: Colors.grey, width: 0.8)),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    unselectedLabelColor: Colors.blue,
                    labelColor: Colors.black,
                    controller: _tabController,
                    tabs: [
                      Tab(text: '', height: 0),
                      Tab(text: '', height: 0),
                      // Tab(text: '', height: 0),
                      // Tab(text: '', height: 0),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                height: MediaQuery.of(context).size.height * 0.7,
                child: TabBarView(
                  controller: _tabController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    // Tab 1: Mobile Number Entry
                    Column(
                      children: [
                        Form(
                          child: CustomForm.textField(
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Visitor Mobile Number",
                            length: 10,
                            textController: _mobileController,
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
                            hintText: '0123456789',
                            prefixIcon: CountryCodePicker(
                              initialSelection: 'IN',
                              favorite: ['IN'],
                              showFlagMain: true,
                              showFlagDialog: true,
                              boxDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                              ),
                              barrierColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.5),
                              closeIcon: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              searchDecoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              textStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                              ),
                              dialogTextStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onChanged: (CountryCode countryCode) {
                                setState(() {
                                  selectedCountryCodeSE = countryCode.code!;
                                });
                              },
                            ),
                            onChanged: (value) {
                              if (value.length == 10) {
                                // Optionally, auto-navigate to OTP tab:
                                // _tabController.animateTo(1);
                              }
                            },
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            isReadOnly: true,
                            counterText:
                                _mobileController.text.length.toString(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (_mobileController.text.isNotEmpty) {
                                  _mobileController.text =
                                      _mobileController.text.substring(
                                          0, _mobileController.text.length - 1);
                                  setState(() {});
                                }
                              },
                              icon: CircleAvatar(
                                backgroundColor: Color(0xffFFEBE6),
                                radius: 20,
                                child: Icon(
                                  size: 22,
                                  Symbols.backspace,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        NumPad(
                          highlightColor: Colors.red,
                          radius: 20,
                          onType: (value) {
                            if (_mobileController.text.length < 10) {
                              _mobileController.text += value;
                              setState(() {});
                            }
                          },
                          numberStyle: Theme.of(context).textTheme.displayLarge,
                          rightWidget: IconButton(
                            icon: const Icon(
                              Symbols.arrow_right_alt_rounded,
                              size: 36,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              final mobileNumber = _mobileController.text;
                              final fullMobileNumber = '${91}$mobileNumber';

                              final username = await _gateStorage.getUsername();
                              log('Full mobile number: $fullMobileNumber');
                              log('Full Username: $username');

                              if (mobileNumber.isEmpty) {
                                myFluttertoast(
                                    msg: 'Mobile number is required',
                                    backgroundColor: Colors.red);
                              } else if (mobileNumber.length != 10) {
                                myFluttertoast(
                                    msg: 'Please enter a 10-digit number',
                                    backgroundColor: Colors.red);
                              } else if (!RegExp(r'^[0-9]+$')
                                  .hasMatch(mobileNumber)) {
                                myFluttertoast(
                                    msg:
                                        'No spaces or special characters allowed',
                                    backgroundColor: Colors.red);
                              } else if (username == fullMobileNumber) {
                                _disableKioskMode();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          GateDashboardView()),
                                );
                              } else {
                                selfCheckInOtp(mobileNumber);
                              }
                            },
                          ),
                        )
                      ],
                    ),
                    // Tab 2: OTP Entry

                    Column(
                      children: [
                        CustomForm.textField(
                          "Enter OTP sent to your mobile number",
                          titleColor: Theme.of(context).colorScheme.onSurface,
                          hintColor: Theme.of(context).colorScheme.onPrimary,
                          textController: _otpController,
                          length: 6,
                          hintText: '123456',
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(6),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          isReadOnly: true,
                          counterText: _start.toString(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              if (_otpController.text.isNotEmpty) {
                                _otpController.text = _otpController.text
                                    .substring(
                                        0, _otpController.text.length - 1);
                                setState(() {});
                              }
                            },
                            icon: CircleAvatar(
                              backgroundColor: Color(0xffFFEBE6),
                              radius: 20,
                              child: Icon(
                                size: 22,
                                Symbols.backspace,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'OTP is required';
                            } else if (value.length != 6) {
                              return 'Please enter a 6-digit OTP';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        NumPad(
                          highlightColor: Colors.red,
                          radius: 20,
                          onType: (value) {
                            if (_otpController.text.length < 6) {
                              _otpController.text += value;
                              setState(() {});
                            }
                          },
                          numberStyle: Theme.of(context).textTheme.displayLarge,
                          rightWidget: IconButton(
                            icon: const Icon(
                              Symbols.arrow_right_alt_rounded,
                              size: 36,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await verifySelfCheckin(
                                  _mobileController.text, _otpController.text);
                              // if (_locationController.text.isNotEmpty) {
                              _captureImageFromCamera();
                              // }
                            },
                          ),
                        )
                      ],
                    ),

                    // Tab 3: Personal Details Entry
                    // Padding(
                    //   padding: const EdgeInsets.all(16.0),
                    //   child: Column(
                    //     children: [
                    //       CustomForm.textField(
                    //         "Your Name",
                    //         titleColor: Theme.of(context).colorScheme.onSurface,
                    //         hintColor: Theme.of(context).colorScheme.onPrimary,
                    //         textController: _nameController,
                    //         hintText: 'Name Surname',
                    //         keyboardType: TextInputType.visiblePassword,
                    //         validator: (value) {
                    //           return 'Please enter your name';
                    //         },
                    //         suffixIcon: IconButton(
                    //           onPressed: () {
                    //             if (_nameController.text.isNotEmpty) {
                    //               FocusScope.of(context)
                    //                   .requestFocus(_locationFocusNode);
                    //             }
                    //           },
                    //           icon: CircleAvatar(
                    //             backgroundColor: Color(0xffFFEBE6),
                    //             radius: 20,
                    //             child: Icon(
                    //               size: 22,
                    //               Symbols.done,
                    //               color: Colors.black,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //       CustomForm.textField(
                    //         "Coming From",
                    //         titleColor: Theme.of(context).colorScheme.onSurface,
                    //         hintColor: Theme.of(context).colorScheme.onPrimary,
                    //         textController: _locationController,
                    //         hintText: 'Mumbai',
                    //         keyboardType: TextInputType.name,
                    //         validator: (value) {
                    //           return 'Location is required';
                    //         },
                    //         suffixIcon: IconButton(
                    //           onPressed: () {},
                    //           icon: CircleAvatar(
                    //             backgroundColor: Color(0xffFFEBE6),
                    //             radius: 20,
                    //             child: Icon(
                    //               size: 22,
                    //               Symbols.done,
                    //               color: Colors.black,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //       SizedBox(height: 32),
                    //       CustomLargeBtn(
                    //         onPressed: () {
                    //           if (_locationController.text.isNotEmpty) {
                    //             _captureImageFromCamera();
                    //           }
                    //         },
                    //         text: "Next",
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    // // Tab 4: Visit Details & Unit Selection (Not displayed; photo capture navigates immediately)
                    // Center(
                    //   child: Text("Processing..."),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelfEntryAd extends StatelessWidget {
  const SelfEntryAd({
    required this.bgImage,
    required this.title,
    required this.subTitle,
    super.key,
  });

  final String bgImage;
  final String title;
  final String subTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300.0,
      width: double.infinity,
      margin: EdgeInsets.all(0),
      child: Stack(
        children: [
          ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.transparent],
              ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
            },
            blendMode: BlendMode.dstIn,
            child: Image.network(
              bgImage,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 25),
                  child: Text(
                    subTitle,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
