import 'package:flutter/material.dart';

class ResponsiveTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabLabels;
  final List<IconData> tabIcons;
  final int currentIndex;
  final EdgeInsetsGeometry padding;

  const ResponsiveTabBar({
    super.key,
    required this.controller,
    required this.tabLabels,
    required this.tabIcons,
    required this.currentIndex,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    for (var i = 0; i < tabLabels.length; i++) {
      tabs.add(
        Tab(
          icon: Icon(tabIcons[i]),
          text: tabLabels[i],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: TabBar(
        controller: controller,
        tabs: tabs,
        isScrollable: true,
      ),
    );
  }
}

