import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// ignore: must_be_immutable
class ErrorNoInternetPage extends StatefulWidget {
  String? error;

  ErrorNoInternetPage({this.error});

  @override
  _ErrorNoInternetPageState createState() =>
      new _ErrorNoInternetPageState(error);
}

class _ErrorNoInternetPageState extends State<ErrorNoInternetPage> {
  TextEditingController userNameController = new TextEditingController();
  String? error;

  _ErrorNoInternetPageState(this.error);

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'No Internet Connection',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20.0,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                    padding: EdgeInsets.fromLTRB(20.0, 35.0, 20.0, 0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Lottie.asset(
                              'assets/json/no_internet.json',
                              height: MediaQuery.of(context).size.height * 0.4,
                              fit: BoxFit.contain,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'No Internet Connection!\n\n',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 22.0,
                                        color: Colors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          "Enjoy a digital detox and explore life beyond the screen. We're continuously checking connectivity and will reconnect you once it's stable.",
                                      style: TextStyle(
                                        height: 1.5,
                                        wordSpacing: 1.3,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18.0,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 35),
                            LinearProgressIndicator(
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.red,
                              ),
                              minHeight: 2.0,
                              semanticsValue: 'Loading...',
                              semanticsLabel: 'Linear progress indicator',
                            ),
                            // Container(
                            //   child: Text(
                            //     'Slow or No Internet Connection \n Please Check your Internet COnnection & Try Again '
                            //             .toLowerCase() +
                            //         "\n\n${getError()}".toUpperCase(),
                            //     textAlign: TextAlign.center,
                            //     style: TextStyle(
                            //         fontFamily: 'Gilroy-Regular',
                            //         letterSpacing: 1.0,
                            //         fontSize: FSTextStyle.h6size,
                            //         color: FsColor.darkgrey),
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  getError() {
    if (error != null) {
      return error;
    } else {
      return "";
    }
  }
}
