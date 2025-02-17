import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class InternetCheckProvider with ChangeNotifier {
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  Timer? _periodicInternetCheckTimer;

  InternetCheckProvider() {
    _startListening();
    _startPeriodicCheck();
  }

  void _startListening() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
          checkInternetAccess(); // Check real access
    });
  }

  void _startPeriodicCheck() {
    _periodicInternetCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (_) {
      checkInternetAccess();
    });
  }

  Future<void> checkInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasConnection =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;

      _updateInternetStatus(hasConnection);
    } catch (_) {
      _updateInternetStatus(false);
    }
  }

  void _updateInternetStatus(bool status) {
    if (_hasInternet != status) {
      _hasInternet = status;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _periodicInternetCheckTimer?.cancel();
    super.dispose();
  }
}
