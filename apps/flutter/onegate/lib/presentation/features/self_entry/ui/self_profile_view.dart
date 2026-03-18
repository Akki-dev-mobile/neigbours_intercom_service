// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, sort_child_properties_last

import 'dart:async';
import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

import '../../../../domain/entities/visitor/visitorLog.dart';

class SelfProfileView extends StatefulWidget {
  final VisitorLog visitorLog;
  final Visitor visitor;
  List<String>? unitList;

  final bool isKioskModeEnabled;

  SelfProfileView(
      {super.key,
      required this.visitorLog,
      this.unitList,
      required this.visitor,
      this.isKioskModeEnabled = true});

  @override
  State<SelfProfileView> createState() => _SelfProfileViewState();
}

class _SelfProfileViewState extends State<SelfProfileView> {
  late Timer _timer;
  double _progressValue = 1.0;
  bool _showApprovalMessage = true;

  @override
  void initState() {
    super.initState();
    log("widget.visitorLog ${widget.visitorLog.toJson()}");
    const totalDurationInSeconds = 15;
    const updateDurationInMilliseconds = 100;

    _timer = Timer(Duration(seconds: totalDurationInSeconds), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SelfHomeView(),
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

    // Hide approval message after a few seconds
    Timer(Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showApprovalMessage = false;
        });
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
                  builder: (context) => SelfHomeView(),
                ),
              );
            },
            icon: Icon(
              Symbols.home_sharp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            label: Text(
              AppLocalizations.of(context).newEntry,
              style: Theme.of(context).textTheme.labelMedium,
            ))
      ],
      pageBody: Stack(
        children: [
          Column(
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
                            widget.visitor.visitor_image ?? '',
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: DashboardLoaderIcon(
                            value: _progressValue,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.red),
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
                        text: '${AppLocalizations.of(context).passId}\n',
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
                    text: widget.visitor.name ?? 'N/A',
                    style: Theme.of(context).textTheme.displayLarge!.copyWith(
                          fontSize: 42,
                        ),
                    children: <TextSpan>[],
                  ),
                ),
              ),
              SelfProfileTile(
                icon: Symbols.phone_in_talk_sharp,
                title: AppLocalizations.of(context).mobile,
                subtitle: widget.visitor.mobile ?? 'N/A',
              ),
              SelfProfileTile(
                icon: Symbols.person_pin_circle_sharp,
                title: AppLocalizations.of(context).comingFrom,
                subtitle: widget.visitorLog.visitor_coming_from ?? 'N/A',
              ),
              SelfProfileTile(
                icon: Symbols.near_me_sharp,
                title: AppLocalizations.of(context).unit,
                subtitle: widget.unitList?.first ?? 'N/A',
              ),
              SelfProfileTile(
                icon: Symbols.groups_3_sharp,
                title: AppLocalizations.of(context).purpose,
                subtitle:
                    widget.visitorLog.visitor_purpose_Category_name ?? 'N/A',
              ),
            ],
          ),

          // Approval message overlay
          if (_showApprovalMessage)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.info,
                      color: Colors.black,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Please wait for some time. You will receive member's approval on your mobile.",
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SelfProfileTile extends StatelessWidget {
  const SelfProfileTile({
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
          color: Theme.of(context).colorScheme.onSurface,
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
