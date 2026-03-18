import 'package:flutter/material.dart';

class ResponsiveTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabLabels;
  final List<IconData> tabIcons;
  final int currentIndex;
  final EdgeInsetsGeometry padding;
  final bool segmented;
  final bool compact;

  const ResponsiveTabBar({
    super.key,
    required this.controller,
    required this.tabLabels,
    required this.tabIcons,
    required this.currentIndex,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.segmented = false,
    this.compact = false,
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

    final tabBar = TabBar(
      controller: controller,
      tabs: tabs,
      isScrollable: !segmented,
      labelPadding: segmented
          ? EdgeInsets.zero
          : (compact ? const EdgeInsets.symmetric(horizontal: 10) : null),
      dividerColor: segmented ? Colors.transparent : null,
      labelColor: segmented ? const Color(0xffc62828) : null,
      unselectedLabelColor:
          segmented ? Colors.grey[600] : null,
      labelStyle: segmented
          ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)
          : null,
      unselectedLabelStyle: segmented
          ? const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)
          : null,
      indicator: segmented
          ? BoxDecoration(
              color: const Color(0xffffe0e3),
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      indicatorPadding: segmented
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
          : EdgeInsets.zero,
      indicatorSize:
          segmented ? TabBarIndicatorSize.tab : TabBarIndicatorSize.label,
    );

    return Padding(
      padding: padding,
      child: segmented
          ? Container(
              padding: EdgeInsets.all(compact ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: tabBar,
            )
          : tabBar,
    );
  }
}
