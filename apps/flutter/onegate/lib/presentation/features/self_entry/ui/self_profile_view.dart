// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, sort_child_properties_last

import 'dart:async';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../dashboard/gatekeeper/pages/gate_bu.dart';

class SelfProfileView extends StatefulWidget {
  const SelfProfileView({super.key});

  @override
  State<SelfProfileView> createState() => _SelfProfileViewState();
}

class _SelfProfileViewState extends State<SelfProfileView> {
  late Timer _timer;
  double _progressValue = 1.0;

  @override
  void initState() {
    super.initState();

    const totalDurationInSeconds = 15;
    const updateDurationInMilliseconds = 100;

    _timer = Timer(Duration(seconds: totalDurationInSeconds), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SelfEntryView(),
        ),
      );
    });

    Timer.periodic(Duration(milliseconds: updateDurationInMilliseconds),
        (timer) {
      setState(() {
        _progressValue -=
            1 / (totalDurationInSeconds * 1000 / updateDurationInMilliseconds);
      });

      if (_progressValue <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      hasBackButton: false,
      pageTitle: 'onegate',
      actions: [
        TextButton.icon(
            onPressed: () {
              _timer.cancel();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => SelfEntryView(),
                ),
              );
            },
            icon: Icon(
              Symbols.home_sharp,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            label: Text(
              'New Entry',
              style: Theme.of(context).textTheme.labelMedium,
            ))
      ],
      pageBody: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50.0,
                      backgroundColor: Colors.blue,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1638957319391-9b81b996afca?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1974&q=80',
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: _progressValue,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        strokeWidth: 4.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  color: Colors.black38,
                  width: 1,
                  height: 80,
                ),
                RichText(
                  text: TextSpan(
                    text: 'Pass ID\n',
                    style: Theme.of(context).textTheme.labelMedium,
                    children: <TextSpan>[
                      TextSpan(
                        text: '#45605890',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 8.0,
              bottom: 20,
            ),
            child: RichText(
              text: TextSpan(
                text: 'Shubham\n',
                style: Theme.of(context).textTheme.displayLarge!.copyWith(
                      fontSize: 42,
                    ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Bane',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SelfProfileTile(
            icon: Symbols.phone_in_talk_sharp,
            title: 'Mobile',
            subtitle: '+91*******101',
          ),
          SelfProfileTile(
            icon: Symbols.person_pin_circle_sharp,
            title: 'Coming From',
            subtitle: 'Mumbai',
          ),
          SelfProfileTile(
            icon: Symbols.near_me_sharp,
            title: 'Host',
            subtitle: '1905/Futurescape',
          ),
          SelfProfileTile(
            icon: Symbols.groups_3_sharp,
            title: 'Purpose',
            subtitle: 'Meeting',
          ),
        ],
      ),
    );
  }
}

class SelfProfileTile extends StatelessWidget {
  SelfProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      isThreeLine: true,
      leading: CircleAvatar(
        radius: 22,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onBackground,
          size: 22,
        ),
        backgroundColor: Color(0xffFFEBE6),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
