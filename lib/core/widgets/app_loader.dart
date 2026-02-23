import 'package:flutter/material.dart';

class AppLoader extends StatelessWidget {
  final double? size;
  final String? title;
  final String? subtitle;
  final IconData? icon;

  const AppLoader({
    super.key,
    this.size,
    this.title,
    this.subtitle,
    this.icon,
  });

  const AppLoader.inline({
    super.key,
    this.size = 16,
    this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );

    if ((title == null || title!.isEmpty) &&
        (subtitle == null || subtitle!.isEmpty) &&
        icon == null) {
      return indicator;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 28),
        indicator,
        if (title != null && title!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            title!,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
