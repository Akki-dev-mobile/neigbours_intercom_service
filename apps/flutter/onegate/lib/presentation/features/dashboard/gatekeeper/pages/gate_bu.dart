// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:async';
import 'package:numpad/numpad.dart';
import 'package:flutter/foundation.dart';

class SelfEntryView extends StatefulWidget {
  const SelfEntryView({super.key});

  @override
  State<SelfEntryView> createState() => _SelfEntryViewState();
}

class _SelfEntryViewState extends State<SelfEntryView> {
  int activeStep = 0;
  String code = "";

  String selectedCountryCodeSE = 'IN';
  late FocusNode _mobileFocusNode;
  late FocusNode _otpFocusNode;

  bool hasOTP = false;
  // final isoCode = selectedCountryCodeSE;

  List<Step> selfEntrySteps() => [
        Step(
          title: Text(context.tr('Account')),
          content: Center(
            child: Text(context.tr('Account')),
          ),
        ),
        Step(
          title: Text(context.tr('Personal')),
          content: Center(
            child: Text(context.tr('Personal')),
          ),
        ),
        Step(
          title: Text(context.tr('Address')),
          content: Center(
            child: Text(context.tr('Address')),
          ),
        ),
      ];
  late Timer _timer;
  int _start = 10;

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

  @override
  void initState() {
    _mobileFocusNode = FocusNode();
    _otpFocusNode = FocusNode();
    Future.delayed(Duration(milliseconds: 200), () {
      FocusScope.of(context).requestFocus(_mobileFocusNode);
    });
    // startKioskMode();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: RichText(
          text: TextSpan(
            text: 'one',
            style: TextStyle(
              fontSize: 28,
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
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Color(0x00FFFFFF),
                expandedHeight: 200.0,
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(0.0),
                  child: SizedBox(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: CarouselSlider(
                    items: [
                      Container(
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
                                'https://images.unsplash.com/photo-1631195092568-a1030d926fd3?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2070&q=80',
                                fit: BoxFit.contain,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 10, 20, 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'One Gate',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(
                                      'Secure your home, control and manage visitors, connect with society gate and much more',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
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
              ),
            ),
          ];
        },
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              Form(
                child: CustomForm.textField(
                  titleColor: Theme.of(context).colorScheme.onBackground,
                  hintColor: Theme.of(context).colorScheme.onPrimary,
                  focusNode: _mobileFocusNode,
                  "Visitor Mobile Number",
                  hintText: context.tr('0123456789'),
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
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    searchDecoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      hintText: context.tr('Search'),
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          style: BorderStyle.solid,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 18,
                    ),
                    dialogTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    onChanged: (CountryCode countryCode) {
                      setState(() {
                        selectedCountryCodeSE = countryCode.code!;
                      });
                    },
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        hasOTP = true;
                        FocusScope.of(context).requestFocus(_otpFocusNode);
                      });
                    },
                    icon: CircleAvatar(
                      backgroundColor:
                          hasOTP ? Color(0xffCAF1D1) : Color(0xffFFEBE6),
                      radius: 20,
                      child: Icon(
                        size: 22,
                        Symbols.done,
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
              hasOTP
                  ? CustomForm.textField(
                      focusNode: _otpFocusNode,
                      titleColor: Theme.of(context).colorScheme.onBackground,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                      "OTP",
                      hintText: context.tr('123456'),
                      textCapitalization: TextCapitalization.characters,
                      length: 6,
                      counterText: '$_start',
                      keyboardType: TextInputType.number,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hasOTP = true;
                          });
                        },
                        icon: CircleAvatar(
                          backgroundColor:
                              hasOTP ? Color(0xffCAF1D1) : Color(0xffFFEBE6),
                          radius: 20,
                          child: Icon(
                            size: 22,
                            Symbols.done,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'OTP is required';
                        } else if (value.length != 6) {
                          return 'Please enter a 6-digit OTP';
                        }
                        return null;
                      },
                    )
                  : SizedBox(),
              NumPad(
                onTap: (val) {
                  if (val == 99) {
                    if (code.isNotEmpty) {
                      setState(() {
                        code = code.substring(0, code.length - 1);
                      });
                    }
                  } else {
                    setState(() {
                      code += "$val";
                    });
                  }
                  print(code);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
