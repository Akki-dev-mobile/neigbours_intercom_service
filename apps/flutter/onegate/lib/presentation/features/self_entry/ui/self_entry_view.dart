// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:numpad_layout/numpad.dart';
import 'package:numpad_layout/widgets/numpad.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  GateStorage _gateStorage = GateStorage();

  // Text controllers.
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();

  // Focus nodes.
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _locationFocusNode = FocusNode();
  final FocusNode _purposeFocusNode = FocusNode();
  final FocusNode _hostFocusNode = FocusNode();
  final _flutterKioskMode = FlutterKioskMode.instance();

  late Timer _timer = Timer(Duration.zero, () {});
  int _start = 10;
  PickedFile? _imageFile;

  late TabController _tabController;

  // Private variable to store the visitor ID returned from API.
  int? _visitorId;

  @override
  void initState() {
    _tabController = TabController(length: 4, vsync: this);
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
      // if (mobileNumber == "7378880544") {
      //   _disableKioskMode();
      // }

      if (result['message'] == 'Visitor is already verified') {
        final visitorData = result['data'];
        final visitor = Visitor(
          id: visitorData['id'],
          name: visitorData['name'] ?? '',
          mobile: visitorData['mobile'] ?? '',
          visitor_image: visitorData['visitor_image'],
        );

        // myFluttertoast(
        //     msg: "Visitor is already verified!", backgroundColor: Colors.red);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnitSelectionView(
              null,
              visitor: visitor,
              guestname: visitor.name ?? '',
              mobileNumber: visitor.mobile ?? '',
              purposeCategory: getPurposeCategory1(null),
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

        final visitor_id = await prefs.getString('visitorId');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnitSelectionView(null,
                visitor: Visitor(
                  id: int.parse(visitor_id ?? ""),
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

  /// Captures an image from the camera.
  /// After capturing the image, it immediately navigates to the UnitSelectionView,
  /// passing along the visitor id (if available) in the Visitor object.
  Future<void> _captureImageFromCamera() async {
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

      _remoteDataSource.createVisitor(Visitor(
        name: _nameController.text,
        mobile: _mobileController.text,
        visitor_image: _imageFile?.path,
      ));

      final prefs = await SharedPreferences.getInstance();

      final visitor_id = await prefs.getString('visitorId');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UnitSelectionView(
            null,
            visitor: Visitor(
              id: int.parse(visitor_id ?? ""),
              name: _nameController.text,
              mobile: _mobileController.text,
            ),
            guestname: _nameController.text,
            mobileNumber: _mobileController.text,
            purposeCategory: getPurposeCategory1(null),
            comingFrom: _locationController.text,
            carNumber: null,
            guestCount: 1,
          ),
        ),
      );
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
                      Tab(text: '', height: 0),
                      Tab(text: '', height: 0),
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
                            },
                          ),
                        )
                      ],
                    ),

                    // Tab 3: Personal Details Entry
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CustomForm.textField(
                            "Your Name",
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            textController: _nameController,
                            hintText: 'Name Surname',
                            keyboardType: TextInputType.visiblePassword,
                            validator: (value) {
                              return 'Please enter your name';
                            },
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (_nameController.text.isNotEmpty) {
                                  FocusScope.of(context)
                                      .requestFocus(_locationFocusNode);
                                }
                              },
                              icon: CircleAvatar(
                                backgroundColor: Color(0xffFFEBE6),
                                radius: 20,
                                child: Icon(
                                  size: 22,
                                  Symbols.done,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          CustomForm.textField(
                            "Coming From",
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            textController: _locationController,
                            hintText: 'Mumbai',
                            keyboardType: TextInputType.name,
                            validator: (value) {
                              return 'Location is required';
                            },
                            suffixIcon: IconButton(
                              onPressed: () {},
                              icon: CircleAvatar(
                                backgroundColor: Color(0xffFFEBE6),
                                radius: 20,
                                child: Icon(
                                  size: 22,
                                  Symbols.done,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 32),
                          CustomLargeBtn(
                            onPressed: () {
                              if (_locationController.text.isNotEmpty) {
                                _captureImageFromCamera();
                              }
                            },
                            text: "Next",
                          ),
                        ],
                      ),
                    ),
                    // Tab 4: Visit Details & Unit Selection (Not displayed; photo capture navigates immediately)
                    Center(
                      child: Text("Processing..."),
                    ),
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
