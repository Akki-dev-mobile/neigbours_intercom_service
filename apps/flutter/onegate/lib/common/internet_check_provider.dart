import 'dart:async';
import 'dart:io';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class InternetCheckProvider with ChangeNotifier {
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  // Expose a broadcast stream for connectivity changes.
  final StreamController<bool> _internetStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get internetStatusStream => _internetStatusController.stream;

  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  Timer? _periodicInternetCheckTimer;

  InternetCheckProvider() {
    // Initial check
    checkInternetAccess();
    _startListening();
    _startPeriodicCheck();
  }

  void _startListening() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      log("Connectivity changed: $result");
      // Perform a real connectivity check.
      checkInternetAccess();
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
    } catch (e) {
      log("Internet check failed: $e");
      _updateInternetStatus(false);
    }
  }

  void _updateInternetStatus(bool status) {
    if (_hasInternet != status) {
      log("Internet status changed: $_hasInternet -> $status");
      _hasInternet = status;
      _internetStatusController.add(status);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _periodicInternetCheckTimer?.cancel();
    _internetStatusController.close();
    super.dispose();
  }
}
