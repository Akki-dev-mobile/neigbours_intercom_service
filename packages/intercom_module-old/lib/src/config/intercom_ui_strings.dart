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
    this.defaultScreenTitle = 'Chat & Call',
    this.chatHistoryTooltip = 'Chat History',
    this.chatsAndCallsHistory = 'Chats & Calls History',
    this.chatsTab = 'Chats',
    this.callsTab = 'Calls',
    this.searchNotImplemented = 'Search not implemented in this demo',
    this.searchHint =
        'Type to search for residents, committee, or groups',
    this.noCallHistory = 'No call history',
    this.callHistoryEmpty = 'Your call history will appear here',
    this.noChatHistory = 'No chat history',
    this.chatHistoryEmpty = 'Your chat conversations will appear here',
    this.noMessagesYet = 'No messages yet',
    this.tapToOpenChat = 'Tap to open chat',
    this.unknownUser = 'Unknown User',
    this.contactFallback = 'Contact',
    this.missedCall = 'Missed',
    this.yesterday = 'Yesterday',
    this.newMessage = 'New message',
    this.cannotMakeCall = 'Cannot Make Call',
    this.callInProgress = 'Call In Progress',
    this.callInProgressMessage =
        'Please finish the current call before starting a new one.',
    this.callFailed = 'Call Failed',
    this.unknownError = 'Unknown error',
    this.permissionsRequired = 'Permissions Required',
    this.cancel = 'Cancel',
    this.openSettings = 'Open Settings',
    this.noValidCallIdentifierBuilder,
    this.daysAgoBuilder,
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
  final String defaultScreenTitle;
  final String chatHistoryTooltip;
  final String chatsAndCallsHistory;
  final String chatsTab;
  final String callsTab;
  final String searchNotImplemented;
  final String searchHint;
  final String noCallHistory;
  final String callHistoryEmpty;
  final String noChatHistory;
  final String chatHistoryEmpty;
  final String noMessagesYet;
  final String tapToOpenChat;
  final String unknownUser;
  final String contactFallback;
  final String missedCall;
  final String yesterday;
  final String newMessage;
  final String cannotMakeCall;
  final String callInProgress;
  final String callInProgressMessage;
  final String callFailed;
  final String unknownError;
  final String permissionsRequired;
  final String cancel;
  final String openSettings;
  final String Function(String contactName)? noValidCallIdentifierBuilder;
  final String Function(int days)? daysAgoBuilder;

  String startingCallLabel(String callTypeDisplayName) =>
      startingCallLabelBuilder?.call(callTypeDisplayName) ??
      'Starting $callTypeDisplayName...';

  String noValidCallIdentifierMessage(String contactName) =>
      noValidCallIdentifierBuilder?.call(contactName) ??
      'No valid call identifier for $contactName';

  String daysAgo(int days) =>
      daysAgoBuilder?.call(days) ?? '$days days ago';
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
