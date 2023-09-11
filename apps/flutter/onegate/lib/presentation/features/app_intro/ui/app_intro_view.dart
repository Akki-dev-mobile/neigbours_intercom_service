// ignore_for_file: prefer_const_constructors

import 'package:concentric_transition/concentric_transition.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../auth/pages/login_view.dart';

final pages = [
  PageData(
    icon: Lottie.network(
      'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/gate222_588a755d7f.json?updated_at=2023-08-23T06:28:50.644Z',
      height: 300,
      width: double.infinity,
    ),
    title: "Introducing onegate your complete digital guardian",
    bgColor: Color(0xFFFFEADD),
    textColor: Color.fromRGBO(66, 66, 66, 1),
  ),
  PageData(
    // icon: Lottie.asset('assets/lottie/gate_intro.json',
    icon: Lottie.network(
      'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/gate_intro_01bd37905f.json?updated_at=2023-08-23T06:28:50.934Z',
      height: 300,
      width: double.infinity,
    ),
    title:
        "Secure your digital world with onegate,\nthe all-in-one security application.",
    textColor: Colors.white,
    bgColor: Color(0xFFFF8989),
  ),
];

class AppIntroView extends StatelessWidget {
  const AppIntroView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ConcentricPageView(
        colors: pages.map((p) => p.bgColor).toList(),
        radius: screenWidth * 0.1,
        nextButtonBuilder: (context) => Padding(
          padding: const EdgeInsets.only(left: 3), // visual center
          child: Icon(
            Icons.navigate_next,
            size: screenWidth * 0.08,
          ),
        ),
        physics: NeverScrollableScrollPhysics(),
        onFinish: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginView(),
            ),
          );
        },
        itemBuilder: (index) {
          final page = pages[index % pages.length];
          return SafeArea(
            child: _Page(page: page),
          );
        },
      ),
    );
  }
}

class PageData {
  final String? title;
  final LottieBuilder? icon;
  final Color bgColor;
  final Color textColor;

  const PageData({
    this.title,
    this.icon,
    this.bgColor = Colors.white,
    this.textColor = Colors.black,
  });
}

class _Page extends StatelessWidget {
  final PageData page;

  const _Page({Key? key, required this.page}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    space(double p) => SizedBox(height: screenHeight * p / 100);
    return Column(
      children: [
        space(10),
        _Image(
          page: page,
        ),
        space(8),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _Text(
            page: page,
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _Text extends StatelessWidget {
  const _Text({
    Key? key,
    required this.page,
    this.style,
  }) : super(key: key);

  final PageData page;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      page.title ?? '',
      style: TextStyle(
        color: page.textColor,
        fontWeight: FontWeight.w600,
        fontFamily: 'Helvetica',
        letterSpacing: 0.0,
        fontSize: 18,
        height: 1.2,
      ).merge(style),
      textAlign: TextAlign.center,
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({
    Key? key,
    required this.page,
  }) : super(key: key);

  final PageData page;

  @override
  Widget build(BuildContext context) {
    return Container(child: page.icon);
  }
}
