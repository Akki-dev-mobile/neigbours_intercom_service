import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future<bool?> myFluttertoast({
  required String msg, // Changed 'message' to 'msg' to match the call
  Color backgroundColor = Colors.green,
  Color textColor = Colors.white,
  toastLength = Toast.LENGTH_SHORT,
  gravity = ToastGravity.BOTTOM,
  timeInSecForIosWeb = 1,
  fontSize = 12,
}) {
  return Fluttertoast.showToast(
      msg: msg, // Using 'msg' as per the function parameter
      backgroundColor: backgroundColor,
      gravity: gravity,
      timeInSecForIosWeb: timeInSecForIosWeb,
      fontSize: fontSize,
      textColor: textColor,
      toastLength: toastLength);
}
