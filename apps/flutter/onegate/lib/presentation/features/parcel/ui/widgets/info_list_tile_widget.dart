import 'package:flutter/material.dart';

class InfoListTileWidget extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final TextStyle? subTitleStyle;

  const InfoListTileWidget(
      {super.key,
      required this.icon,
      this.iconColor,
      this.iconBgColor,
      required this.title,
      required this.subtitle,
      this.trailing,
      this.titleStyle,
      this.subTitleStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor ?? Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: subTitleStyle ??
              Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 18),
        ),
        trailing: trailing,
      ),
    );
  }
}
