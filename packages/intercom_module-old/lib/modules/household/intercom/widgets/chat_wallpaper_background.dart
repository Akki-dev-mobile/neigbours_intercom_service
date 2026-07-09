import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../src/config/intercom_module_config.dart';

/// Default chat wallpaper from the host app asset bundle.
class ChatWallpaperBackground extends StatelessWidget {
  final File? customWallpaper;
  final double opacity;

  const ChatWallpaperBackground({
    super.key,
    this.customWallpaper,
    this.opacity = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Opacity(
        opacity: opacity,
        child: customWallpaper != null
            ? Image.file(
                customWallpaper!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAsset(context);
                },
              )
            : _buildDefaultAsset(context),
      ),
    );
  }

  Widget _buildDefaultAsset(BuildContext context) {
    if (!IntercomModule.isConfigured) {
      debugPrint(
        'ChatWallpaperBackground: IntercomModule not configured; using fallback color',
      );
      return const SizedBox.shrink();
    }

    final config = IntercomModule.config;
    final builder = config.chatBackgroundBuilder;
    if (builder != null) {
      return builder(context);
    }

    final path = config.chatBackgroundAssetPath;
    if (path == null || path.trim().isEmpty) {
      debugPrint(
        'ChatWallpaperBackground: chatBackgroundAssetPath is empty; using fallback color',
      );
      return const SizedBox.shrink();
    }

    final package = config.chatBackgroundAssetPackage;

    // Prefer the host app asset bundle (no package) when available.
    if (package == null || package.trim().isEmpty) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load chat wallpaper (path=$path): $error');
          return Container(color: const Color(0xFFF0F2F5));
        },
      );
    }

    return Image.asset(
      path,
      package: package,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'Failed to load chat wallpaper '
          '(path=$path, package=$package): $error',
        );
        return Image.asset(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, hostError, stackTrace) {
            debugPrint(
              'Failed to load chat wallpaper from host bundle '
              '(path=$path): $hostError',
            );
            return Container(color: const Color(0xFFF0F2F5));
          },
        );
      },
    );
  }
}
