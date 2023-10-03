// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_onegate/presentation/features/auth/pages/login_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:numpad_layout/extension/numbers.dart';
import 'package:numpad_layout/numpad.dart';
import 'package:numpad_layout/widgets/num_button.dart';
import 'package:numpad_layout/widgets/numpad.dart';
import 'package:page_transition/page_transition.dart';

import 'self_profile_view.dart';

class SelfEntryView extends StatefulWidget {
  const SelfEntryView({super.key});

  @override
  State<SelfEntryView> createState() => _SelfEntryViewState();
}

class _SelfEntryViewState extends State<SelfEntryView>
    with TickerProviderStateMixin {
  int activeStep = 0;
  String code = "";
  String selectedCountryCodeSE = 'IN';
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();

  FocusNode _nameFocusNode = FocusNode();
  FocusNode _locationFocusNode = FocusNode();
  FocusNode _purposeFocusNode = FocusNode();
  FocusNode _hostFocusNode = FocusNode();

  late Timer _timer;
  int _start = 10;
  PickedFile? _imageFile;

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  Future<void> _captureImageFromCamera() async {
    final picker = ImagePicker();

    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _imageFile = PickedFile(image.path);
      });
      _tabController.animateTo(
        (_tabController.index + 1),
      );
      Future.delayed(Duration(milliseconds: 200), () {
        FocusScope.of(context).requestFocus(_purposeFocusNode);
      });
    } catch (e) {
      print('Error capturing image from camera: $e');
    }
  }

  late TabController _tabController;
  @override
  void initState() {
    _tabController = TabController(length: 4, vsync: this);

    // startKioskMode();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                    color: Colors.red,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: 'gate',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: Icon(
                    Symbols.qr_code,
                    color: Colors.black,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: CarouselSlider(
                  items: [
                    SelfEntryAd(
                      bgImage:
                          'https://images.unsplash.com/photo-1631195092568-a1030d926fd3?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2070&q=80',
                      title: 'onegate',
                      subTitle:
                          'Secure your home and manage visitors, connect with society gate and much more',
                    ),
                    SelfEntryAd(
                      bgImage:
                          'https://images.unsplash.com/photo-1496065187959-7f07b8353c55?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80',
                      title: 'oneapp',
                      subTitle: 'The ALL in One App',
                    ),
                    SelfEntryAd(
                      bgImage:
                          'https://images.unsplash.com/photo-1580041065738-e72023775cdc?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80',
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
                    //This is for background color
                    color: Colors.white.withOpacity(0.0),
                    //This is for bottom border that is needed
                    border: Border(
                        bottom: BorderSide(color: Colors.grey, width: 0.8)),
                  ),
                  child: TabBar(
                    // isScrollable: true,R
                    indicatorSize: TabBarIndicatorSize.tab,
                    unselectedLabelColor: Colors.blue,
                    // indicator: BoxDecoration(
                    //   color: Colors.red,
                    // ),
                    labelColor: Colors.black,
                    controller: _tabController,
                    tabs: [
                      Tab(
                        text: '',
                        height: 0,
                      ),
                      Tab(
                        text: '',
                        height: 0,
                      ),
                      Tab(
                        text: '',
                        height: 0,
                      ),
                      Tab(
                        text: '',
                        height: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                height: MediaQuery.of(context).size.height * 0.7,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Column(
                      children: [
                        Form(
                          child: CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Visitor Mobile Number",
                            textController: _mobileController,
                            hintText: '0123456789',
                            prefixIcon: CountryCodePicker(
                              initialSelection: 'IN',
                              favorite: ['IN'],
                              showFlagMain: true,
                              showFlagDialog: true,
                              boxDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.background,
                              ),
                              barrierColor: Theme.of(context)
                                  .colorScheme
                                  .background
                                  .withOpacity(0.5),
                              closeIcon: Icon(
                                Icons.close,
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                              searchDecoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                                hintText: 'Search',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                  ),
                                ),
                              ),
                              textStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                                fontSize: 18,
                              ),
                              dialogTextStyle: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                              ),
                              onChanged: (CountryCode countryCode) {
                                setState(() {
                                  selectedCountryCodeSE = countryCode.code!;
                                });
                              },
                            ),
                            onChanged: (value) {
                              if (value.length == 10) {
                                _tabController
                                    .animateTo((_tabController.index + 1) % 3);
                              }
                            },
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
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
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Mobile number is required';
                              } else if (value.length != 10) {
                                return 'Please enter a 10-digit number';
                              }
                              return null;
                            },
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
                              if (_mobileController.text == '0123456789') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginView(),
                                  ),
                                );
                              } else {
                                _tabController
                                    .animateTo((_tabController.index + 1) % 3);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Form(
                          child: CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Enter OTP sent to your mobile number",
                            textController: _otpController,
                            hintText: '123456',
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(6),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            isReadOnly: true,
                            counterText: _otpController.text.length.toString(),
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
                            length: 10,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'OTP is required';
                              } else if (value.length != 10) {
                                return 'Please enter a 6-digit number';
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
                            onPressed: () {
                              _tabController
                                  .animateTo((_tabController.index + 1) % 3);
                            },
                          ),
                        ),
                      ],
                    ),
                    Form(
                      child: Column(
                        children: [
                          CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
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
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Coming From",
                            focusNode: _locationFocusNode,
                            textController: _locationController,
                            hintText: 'Mumbai',
                            keyboardType: TextInputType.name,
                            validator: (value) {
                              return 'Location is required';
                            },
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (_locationController.text.isNotEmpty) {
                                  _captureImageFromCamera();
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
                    Form(
                      child: Column(
                        children: [
                          CustomForm.textField(
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
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
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            "Select Host",
                            textController: _hostController,
                            focusNode: _hostFocusNode,
                            hintText: 'Mr. Shubham Bane',
                            isReadOnly: false,
                            keyboardType: TextInputType.visiblePassword,
                            validator: (value) {
                              return 'Host is required';
                            },
                            suffixIcon: IconButton(
                              onPressed: () {
                                if (_hostController.text.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    PageTransition(
                                      type: PageTransitionType.rightToLeft,
                                      child: SelfProfileView(),
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
                colors: [
                  Colors.black,
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromLTRB(
                  0,
                  0,
                  rect.width,
                  rect.height,
                ),
              );
            },
            blendMode: BlendMode.dstIn,
            child: Image.network(
              bgImage,
              // 'https://images.unsplash.com/photo-1631195092568-a1030d926fd3?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2070&q=80',
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
                  padding: const EdgeInsets.only(
                    top: 10,
                    bottom: 25,
                  ),
                  child: Text(
                    subTitle,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
