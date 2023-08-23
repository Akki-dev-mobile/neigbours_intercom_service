import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';

class Temp extends StatefulWidget {
  const Temp({super.key});

  @override
  State<Temp> createState() => _TempState();
}

class _TempState extends State<Temp> {
  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageBody: Container(),
    );
  }
}
