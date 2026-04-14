import 'package:flutter/material.dart';
import 'package:neigbours_intercom_service/intercom/pages/create_group_page.dart';
import 'package:neigbours_intercom_service/core/utils/navigation_helper.dart';

class CreateGroupTestPage extends StatelessWidget {
  const CreateGroupTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CreateGroup Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            NavigationHelper.pushRoute(
              context,
              MaterialPageRoute(builder: (context) => const CreateGroupPage()),
            );
          },
          child: const Text('Open Create Group Page'),
        ),
      ),
    );
  }
}
