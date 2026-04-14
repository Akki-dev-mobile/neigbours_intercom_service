import 'package:flutter/material.dart';
import 'package:neigbours_intercom_service/core/theme/colors.dart';
import 'package:neigbours_intercom_service/intercom/tabs/groups_tab.dart';
import 'package:neigbours_intercom_service/intercom/tabs/residents_tab.dart';
import 'package:neigbours_intercom_service/intercom/tabs/committee_tab.dart';
import 'package:neigbours_intercom_service/neighbours/neighbours_config.dart';

/// Neighbours hub: Groups, Residents, Committee tabs (shared with the main app).
class NeighbourScreen extends StatefulWidget {
  const NeighbourScreen({
    super.key,
    this.config = const NeighboursConfig(),
  });

  /// Host-defined toggles (posting, roles, etc.).
  final NeighboursConfig config;

  @override
  State<NeighbourScreen> createState() => _NeighbourScreenState();
}

/// US spelling alias for [NeighbourScreen].
typedef NeighboursScreen = NeighbourScreen;

class _NeighbourScreenState extends State<NeighbourScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);
  int _previousTabIndex = 0;

  final ValueNotifier<bool> _groupsTabLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _residentsTabLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _committeeTabLoading = ValueNotifier<bool>(false);

  bool get _isTabSwitchingDisabled {
    return _groupsTabLoading.value ||
        _residentsTabLoading.value ||
        _committeeTabLoading.value;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    _groupsTabLoading.addListener(_onLoadingStateChanged);
    _residentsTabLoading.addListener(_onLoadingStateChanged);
    _committeeTabLoading.addListener(_onLoadingStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _activeTabNotifier.value = _tabController.index;
      }
    });
  }

  void _onLoadingStateChanged() {
    if (!mounted) return;

    if (_isTabSwitchingDisabled) {
      debugPrint(
        '🔒 [NeighbourScreen] Tab switching disabled (tab ${_tabController.index} is loading)',
      );
    } else {
      debugPrint('🔓 [NeighbourScreen] Tab switching enabled (all tabs loaded)');
    }

    setState(() {});
  }

  void _handleTabChange() {
    final newIndex = _tabController.index;

    if (_tabController.indexIsChanging) {
      if (newIndex != _previousTabIndex) {
        debugPrint(
          '🔄 [NeighbourScreen] Tab changing during animation: $_previousTabIndex → $newIndex',
        );

        final targetTabLoading = (newIndex == 0 && _groupsTabLoading.value) ||
            (newIndex == 1 && _residentsTabLoading.value) ||
            (newIndex == 2 && _committeeTabLoading.value);

        if (!targetTabLoading) {
          _previousTabIndex = newIndex;
          _activeTabNotifier.value = newIndex;
        } else {
          debugPrint(
            '⏸️ [NeighbourScreen] Tab switch during animation blocked - target tab ($newIndex) is loading',
          );
        }
      }
    } else {
      final targetTabLoading = (newIndex == 0 && _groupsTabLoading.value) ||
          (newIndex == 1 && _residentsTabLoading.value) ||
          (newIndex == 2 && _committeeTabLoading.value);

      if (targetTabLoading) {
        debugPrint(
          '⏸️ [NeighbourScreen] Tab switch blocked - target tab ($newIndex) is still loading',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.index != _previousTabIndex) {
            _tabController.animateTo(_previousTabIndex);
          }
        });
        return;
      }

      final shouldShowIcon = newIndex == 1 || newIndex == 2;
      final previousShouldShow = _previousTabIndex == 1 || _previousTabIndex == 2;

      if (shouldShowIcon != previousShouldShow) {
        setState(() {});
      }

      if (newIndex != _previousTabIndex) {
        _previousTabIndex = newIndex;
        _activeTabNotifier.value = newIndex;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _groupsTabLoading.removeListener(_onLoadingStateChanged);
    _residentsTabLoading.removeListener(_onLoadingStateChanged);
    _committeeTabLoading.removeListener(_onLoadingStateChanged);
    _tabController.dispose();
    _activeTabNotifier.dispose();
    _groupsTabLoading.dispose();
    _residentsTabLoading.dispose();
    _committeeTabLoading.dispose();
    super.dispose();
  }

  bool get _shouldShowChatHistoryIcon {
    final currentIndex = _tabController.index;
    return currentIndex == 1 || currentIndex == 2;
  }

  void _showCallHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => DefaultTabController(
          length: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Call & Chat History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.call),
                      text: 'Calls',
                    ),
                    Tab(
                      icon: Icon(Icons.chat),
                      text: 'Chats',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(top: 8),
                        children: const [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text('Call History'),
                            subtitle: Text('No calls yet'),
                          ),
                        ],
                      ),
                      ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(top: 8),
                        children: const [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text('Chat History'),
                            subtitle: Text('No chats yet'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Neighbours'),
        actions: _shouldShowChatHistoryIcon
            ? [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _showCallHistory,
                  tooltip: 'Chat History',
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            final targetTabLoading = (index == 0 && _groupsTabLoading.value) ||
                (index == 1 && _residentsTabLoading.value) ||
                (index == 2 && _committeeTabLoading.value);

            if (targetTabLoading) {
              debugPrint(
                '⏸️ [NeighbourScreen] Tab switch prevented - target tab ($index) is loading',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please wait for data to load...'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            _tabController.animateTo(index);
          },
          tabs: [
            Tab(
              text: 'Groups',
              child: ValueListenableBuilder<bool>(
                valueListenable: _groupsTabLoading,
                builder: (context, isLoading, child) {
                  return isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Groups'),
                          ],
                        )
                      : const Text('Groups');
                },
              ),
            ),
            Tab(
              text: 'Residents',
              child: ValueListenableBuilder<bool>(
                valueListenable: _residentsTabLoading,
                builder: (context, isLoading, child) {
                  return isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Residents'),
                          ],
                        )
                      : const Text('Residents');
                },
              ),
            ),
            Tab(
              text: 'Committee',
              child: ValueListenableBuilder<bool>(
                valueListenable: _committeeTabLoading,
                builder: (context, isLoading, child) {
                  return isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Committee'),
                          ],
                        )
                      : const Text('Committee');
                },
              ),
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _groupsTabLoading,
        builder: (context, groupsLoading, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: _residentsTabLoading,
            builder: (context, residentsLoading, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _committeeTabLoading,
                builder: (context, committeeLoading, _) {
                  final anyTabLoading =
                      groupsLoading || residentsLoading || committeeLoading;

                  return TabBarView(
                    controller: _tabController,
                    physics: anyTabLoading
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    children: [
                      GroupsTab(
                        activeTabNotifier: _activeTabNotifier,
                        tabIndex: 0,
                        loadingNotifier: _groupsTabLoading,
                      ),
                      ResidentsTab(
                        activeTabNotifier: _activeTabNotifier,
                        tabIndex: 1,
                        loadingNotifier: _residentsTabLoading,
                      ),
                      CommitteeTab(
                        activeTabNotifier: _activeTabNotifier,
                        tabIndex: 2,
                        loadingNotifier: _committeeTabLoading,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
