// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kiosk_mode/flutter_kiosk_mode.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/face_id_registration_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/passcode_entry_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/qr_scanner_self.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/self_entry_facerec_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/self_entry_view.dart'
    as self_entry;
import 'package:material_symbols_icons/symbols.dart';

import 'ui/self_entry_view.dart';

class SelfHomeView extends StatefulWidget {
  final bool isKioskModeEnabled;

  const SelfHomeView({
    this.isKioskModeEnabled = true,
    super.key,
  });

  @override
  State<SelfHomeView> createState() => _SelfHomeViewState();
}

class _SelfHomeViewState extends State<SelfHomeView> {
  final _flutterKioskMode = FlutterKioskMode.instance();

  @override
  void initState() {
    deleteImage();
    super.initState();
  }

  Future<void> deleteImage() async {
    GateStorage storage = GateStorage();
    await storage.init();
    await storage.removeVisitorImage();
    print("Image successfully removed.");
  }

  void enterKioskMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Hide status bar
      systemNavigationBarColor: Colors.transparent, // Hide navigation bar
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              backgroundColor: Colors.white54,
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
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(
                    'Self Check-in',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Symbols.info,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    self_entry.SelfEntryView(),
                              ),
                            );
                          },
                          child: SelfTapOption(
                            fTitle: 'Mobile',
                            sTitle: 'Number',
                            image: 'assets/media/images/Standing.png',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PasscodeEntryView()));
                          },
                          child: SelfTapOption(
                            fTitle: 'Pass',
                            sTitle: 'Code',
                            image: 'assets/media/images/Space.png',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                (MaterialPageRoute(
                                    builder: (context) =>
                                        QRScannerScreen(self_checkin: true))));
                          },
                          child: SelfTapOption(
                            fTitle: 'Scan',
                            sTitle: 'QR',
                            image: 'assets/media/images/standing2.png',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SelfEntryFacerecView(),
                              ),
                            );
                          },
                          child: SelfTapOption(
                            fTitle: 'Scan',
                            sTitle: 'Face',
                            image: 'assets/media/images/Sitting.png',
                          ),
                        ),
                      ],
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

class SelfTapOption extends StatelessWidget {
  const SelfTapOption({
    super.key,
    required this.fTitle,
    required this.sTitle,
    required this.image,
  });

  final String fTitle;
  final String sTitle;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.22,
        width: MediaQuery.of(context).size.width * 0.45,
        decoration: BoxDecoration(
          color: Color(0x80F3F3F3),
          borderRadius: BorderRadius.all(
            Radius.circular(25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: fTitle,
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: '\n$sTitle',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(
              image,
              height: MediaQuery.of(context).size.height * 0.10,
            ),
          ],
        ),
      ),
    );
  }
}
