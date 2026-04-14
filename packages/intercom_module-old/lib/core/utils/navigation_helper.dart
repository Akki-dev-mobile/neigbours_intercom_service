import 'package:flutter/material.dart';

class NavigationHelper {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  static Future<T?> pushRoute<T>(
    BuildContext context,
    dynamic routeOrBuilderOrPage, {
    String? title,
    String? subtitle,
    IconData? icon,
    bool fullscreenDialog = false,
    PreferredSizeWidget? customAppBar,
  }) {
    if (routeOrBuilderOrPage is Route<T>) {
      return Navigator.of(context).push<T>(routeOrBuilderOrPage);
    }

    late final WidgetBuilder builder;
    if (routeOrBuilderOrPage is WidgetBuilder) {
      builder = routeOrBuilderOrPage;
    } else if (routeOrBuilderOrPage is Widget) {
      builder = (_) => routeOrBuilderOrPage;
    } else {
      throw ArgumentError('pushRoute expects a Route, WidgetBuilder, or Widget');
    }

    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        fullscreenDialog: fullscreenDialog,
        builder: (ctx) {
          final child = builder(ctx);
          if (customAppBar == null &&
              title == null &&
              subtitle == null &&
              icon == null) {
            return child;
          }
          return Scaffold(
            appBar: customAppBar ??
                AppBar(
                  title: Text(title ?? ''),
                ),
            body: child,
          );
        },
      ),
    );
  }

  static Future<T?> replaceWithWidget<T>(
    BuildContext context,
    dynamic builderOrPage, {
    bool fullscreenDialog = false,
    PreferredSizeWidget? customAppBar,
  }) {
    late final WidgetBuilder builder;
    if (builderOrPage is WidgetBuilder) {
      builder = builderOrPage;
    } else if (builderOrPage is Widget) {
      builder = (_) => builderOrPage;
    } else {
      throw ArgumentError('replaceWithWidget expects a WidgetBuilder or Widget');
    }

    return Navigator.of(context).pushReplacement<T, T>(
      MaterialPageRoute(
        fullscreenDialog: fullscreenDialog,
        builder: (ctx) {
          final child = builder(ctx);
          if (customAppBar == null) return child;
          return Scaffold(appBar: customAppBar, body: child);
        },
      ),
    );
  }

  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }
}
