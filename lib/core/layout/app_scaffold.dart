import 'package:flutter/material.dart';

class AppScaffold {
  static Widget internal({
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? customAppBar,
    required Widget body,
  }) {
    return Scaffold(
      appBar: customAppBar ??
          AppBar(
            title: Text(title),
            actions: actions,
          ),
      body: body,
    );
  }
}
