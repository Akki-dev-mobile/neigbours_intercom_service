// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:numpad_layout/numpad.dart';
import 'package:numpad_layout/widgets/numpad.dart';

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

  late Timer _timer;
  int _start = 10;
  PickedFile? _imageFile;

  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 4, vsync: this);
    super.initState();
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
  /// On success, it navigates to Tab 2 (OTP entry) and starts a default 10-second timer.
  void selfCheckInOtp(String mobileNumber) async {
    try {
      await _remoteDataSource.sendOtpForSelfCheckIn(mobileNumber);
      print('OTP sent successfully.');
      _tabController.animateTo(1);
      _start = 10; // Default timer value.
      startTimer();
    } catch (e) {
      print('Error sending OTP: $e');
      myFluttertoast(msg: "Error sending OTP. Please try again.");
    }
  }

  /// Verifies the self-checkin OTP.
  /// If verification is successful, a success toast is shown and we navigate to Tab 3 (Personal Details).
  Future<void> verifySelfCheckin(String mobileNumber, String otp) async {
    try {
      final result = await _remoteDataSource.verifySelfCheckin(
        mobileNumber: mobileNumber,
        otp: otp,
      );
      log('OTP verification successful: $result');

      // Check if visitor is already verified:
      if (result is Map<String, dynamic> &&
          result['data'] == null &&
          result['message'] == 'Visitor is already verified') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnitSelectionView(
              null, // searchedVisitor: not applicable in self-checkin.
              visitor: Visitor(
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
        return;
      }
      myFluttertoast(msg: "OTP verified successfully!");
      // Otherwise, proceed to the Personal Details tab.
      _tabController.animateTo(2);
    } catch (e) {
      log('Error during OTP verification: $e');
      myFluttertoast(msg: "OTP verification failed. Please try again.");
    }
  }

  /// Converts a purpose category string (JSON or ID) into a PurposeCategory1 instance.
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

  /// Captures an image from the camera.
  /// After capturing the image, it immediately navigates to the Unit Selection View.
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
      // After capturing the image, navigate directly to UnitSelectionView.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UnitSelectionView(
            null,
            visitor: Visitor(
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
      print('Error capturing image from camera: $e');
    }
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
                            textController: _mobileController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Mobile number is required';
                              } else if (value.length != 10) {
                                return 'Please enter a 10-digit number';
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
                            length: 10,
                          ),
                        ),
                        NumPad(
                          highlightColor: Colors.red,
                          radius: 20,
                          onType: (value) {
                            _mobileController.text += value;
                            setState(() {});
                          },
                          numberStyle: Theme.of(context).textTheme.displayLarge,
                          rightWidget: IconButton(
                            icon: const Icon(
                              Symbols.arrow_right_alt_rounded,
                              size: 36,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              selfCheckInOtp(_mobileController.text);
                            },
                          ),
                        ),
                      ],
                    ),
                    // Tab 2: OTP Entry
                    Column(
                      children: [
                        Form(
                          child: CustomForm.textField(
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Enter OTP sent to your mobile number",
                            textController: _otpController,
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
                        ),
                        NumPad(
                          highlightColor: Colors.red,
                          radius: 20,
                          onType: (value) {
                            _otpController.text += value;
                            setState(() {});
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
                        ),
                      ],
                    ),
                    // Tab 3: Personal Details Entry
                    Column(
                      children: [
                        Form(
                          child: Column(
                            children: [
                              CustomForm.textField(
                                titleColor:
                                    Theme.of(context).colorScheme.onSurface,
                                hintColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                "Your Name",
                                textController: _nameController,
                                focusNode: _nameFocusNode,
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
                                titleColor:
                                    Theme.of(context).colorScheme.onSurface,
                                hintColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                "Coming From",
                                focusNode: _locationFocusNode,
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
                      ],
                    ),
                    // Tab 4: Visit Details & Unit Selection
                    Form(
                      child: Column(
                        children: [
                          CustomForm.textField(
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Purpose of visit",
                            textController: _purposeController,
                            focusNode: _purposeFocusNode,
                            hintText: 'Meeting',
                            keyboardType: TextInputType.visiblePassword,
                            validator: (value) {
                              return 'Purpose of visit is required';
                            },
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (_purposeController.text.isNotEmpty) {
                                  FocusScope.of(context)
                                      .requestFocus(_hostFocusNode);
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
                            titleColor: Theme.of(context).colorScheme.onSurface,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Select Unit",
                            textController: _hostController,
                            focusNode: _hostFocusNode,
                            hintText: 'Select Host Unit',
                            isReadOnly: true,
                            keyboardType: TextInputType.visiblePassword,
                            validator: (value) {
                              return 'Host is required';
                            },
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (_hostController.text.isNotEmpty) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UnitSelectionView(
                                        null,
                                        visitor: Visitor(
                                          name: _nameController.text,
                                          mobile: _mobileController.text,
                                        ),
                                        guestname: _nameController.text,
                                        mobileNumber: _mobileController.text,
                                        purposeCategory:
                                            getPurposeCategory1(null),
                                        comingFrom: _locationController.text,
                                        carNumber: null,
                                        guestCount: 1,
                                      ),
                                    ),
                                  );
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
                        ],
                      ),
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
