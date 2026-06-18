import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Host-app supplied UI strings for the intercom module.
///
/// Defaults are English so the module stays usable without localization wiring.
@immutable
class IntercomUiStrings {
  const IntercomUiStrings({
    this.residents = 'Residents',
    this.committee = 'Committee',
    this.groups = 'Groups',
    this.posts = 'Posts',
    this.gatekeepers = 'Gatekeepers',
    this.societyOffice = 'Society Office',
    this.lobbies = 'Lobbies',
    this.startCall = 'Start a Call',
    this.audioCall = 'Audio Call',
    this.audioCallSubtitle = 'Voice only',
    this.videoCall = 'Video Call',
    this.videoCallSubtitle = 'Video & voice',
    this.connecting = 'Connecting...',
    this.startingCallLabelBuilder,
  });

  static const IntercomUiStrings defaults = IntercomUiStrings();

  final String residents;
  final String committee;
  final String groups;
  final String posts;
  final String gatekeepers;
  final String societyOffice;
  final String lobbies;
  final String startCall;
  final String audioCall;
  final String audioCallSubtitle;
  final String videoCall;
  final String videoCallSubtitle;
  final String connecting;
  final String Function(String callTypeDisplayName)? startingCallLabelBuilder;

  String startingCallLabel(String callTypeDisplayName) =>
      startingCallLabelBuilder?.call(callTypeDisplayName) ??
      'Starting $callTypeDisplayName...';
}

/// Makes [IntercomUiStrings] available to intercom tabs and call UI widgets.
class IntercomUiStringsScope extends InheritedWidget {
  const IntercomUiStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final IntercomUiStrings strings;

  static IntercomUiStrings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<IntercomUiStringsScope>();
    return scope?.strings ?? IntercomUiStrings.defaults;
  }

  @override
  bool updateShouldNotify(IntercomUiStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
