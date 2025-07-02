import 'dart:async';
import 'dart:io';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InternetCheckProvider with ChangeNotifier {
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  // Expose a broadcast stream for connectivity changes
  final StreamController<bool> _internetStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get internetStatusStream => _internetStatusController.stream;

  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  Timer? _periodicInternetCheckTimer;
  bool _isCheckingConnection = false;

  // List of reliable endpoints to check connectivity
  final List<String> _reliableEndpoints = [
    'https://www.google.com',
    'https://www.cloudflare.com',
    '1.1.1.1',
    '8.8.8.8'
  ];

  InternetCheckProvider() {
    _initializeConnectivityChecks();
  }

  void _initializeConnectivityChecks() {
    // Initial check
    checkInternetAccess();

    // Start listening to connectivity changes
    _startListening();

    // Start periodic checks
    _startPeriodicCheck();

    log('🌐 Internet connectivity monitoring initialized');
  }

  void _startListening() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      log("🔄 Connectivity changed: $result");
      // Perform a real connectivity check when the status changes
      checkInternetAccess();
    });
  }

  void _startPeriodicCheck() {
    _periodicInternetCheckTimer?.cancel();
    _periodicInternetCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
      checkInternetAccess();
    });
  }

  Future<void> checkInternetAccess() async {
    if (_isCheckingConnection) return;
    _isCheckingConnection = true;

    try {
      // First check connectivity status
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _updateInternetStatus(false);
        _isCheckingConnection = false;
        return;
      }

      // Try multiple endpoints for reliability
      bool hasConnection = false;
      for (final endpoint in _reliableEndpoints) {
        try {
          if (endpoint.startsWith('http')) {
            // HTTP check
            final response = await http
                .get(Uri.parse(endpoint))
                .timeout(const Duration(seconds: 5));
            if (response.statusCode == 200) {
              hasConnection = true;
              break;
            }
          } else {
            // DNS lookup check
            final result = await InternetAddress.lookup(endpoint)
                .timeout(const Duration(seconds: 5));
            if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
              hasConnection = true;
              break;
            }
          }
        } catch (e) {
          log("⚠️ Failed to check endpoint $endpoint: $e");
          continue;
        }
      }

      _updateInternetStatus(hasConnection);
    } catch (e) {
      log("❌ Internet check failed: $e");
      _updateInternetStatus(false);
    } finally {
      _isCheckingConnection = false;
    }
  }

  void _updateInternetStatus(bool status) {
    if (_hasInternet != status) {
      log("🌐 Internet status changed: $_hasInternet -> $status");
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
