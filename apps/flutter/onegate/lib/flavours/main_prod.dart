import 'package:flutter/material.dart';
import 'package:flutter_onegate/flavours/config/environment.dart';
import 'package:flutter_onegate/main.dart';

void main() {
  Environment.init('prod');
  runApp(MyApp());
}