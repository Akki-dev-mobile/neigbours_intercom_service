import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorApprovalTimeProvider extends ChangeNotifier {
  int _approvalTime = 120; // Default value

  int get approvalTime => _approvalTime;

  VisitorApprovalTimeProvider() {
    _loadApprovalTime();
  }

  Future<void> _loadApprovalTime() async {
    final prefs = await SharedPreferences.getInstance();
    _approvalTime = prefs.getInt('visitor_approval_time') ?? 120;
    notifyListeners();
  }

  Future<void> setApprovalTime(int newTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('visitor_approval_time', newTime);
    _approvalTime = newTime;
    notifyListeners();
  }
}
