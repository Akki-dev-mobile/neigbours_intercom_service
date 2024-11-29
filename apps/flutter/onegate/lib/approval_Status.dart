import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ApprovalStatusScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = Provider.of<ApprovalStatusProvider>(context).status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Status'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == "Waiting for approval...")
              CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              status,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class ApprovalStatusProvider extends ChangeNotifier {
  String _status = "Waiting for approval...";

  String get status => _status;

  void setApprovalStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }
}
