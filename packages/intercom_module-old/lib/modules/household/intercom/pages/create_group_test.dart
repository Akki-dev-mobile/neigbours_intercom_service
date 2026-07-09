import 'package:flutter/material.dart';
import 'create_group_page.dart';
import '../../../../core/utils/navigation_helper.dart';
import '../../../../src/config/chat_call_i18n.dart';

class CreateGroupTestPage extends StatelessWidget {
  const CreateGroupTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          chatCallTr(
            context,
            'chatCall_createGroupTest',
            fallback: 'CreateGroup Test',
          ),
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            NavigationHelper.pushRoute(
              context,
              MaterialPageRoute(builder: (context) => const CreateGroupPage()),
            );
          },
          child: Text(
            chatCallTr(
              context,
              'chatCall_openCreateGroupPage',
              fallback: 'Open Create Group Page',
            ),
          ),
        ),
      ),
    );
  }
}
