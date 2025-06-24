import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/notifications/notification_manager.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:ionicons/ionicons.dart';

/// Screen for viewing and managing custom notifications
class CustomNotificationsScreen extends StatefulWidget {
  const CustomNotificationsScreen({super.key});

  @override
  State<CustomNotificationsScreen> createState() =>
      _CustomNotificationsScreenState();
}

class _CustomNotificationsScreenState extends State<CustomNotificationsScreen> {
  final NotificationManager _notificationManager = NotificationManager();
  
  List<NotificationMessage> _notifications = [];
  NotificationStats? _stats;
  String? _selectedTopic;
  AlertPriority? _selectedPriority;
  bool _showUnreadOnly = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await _notificationManager.initialize();
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error initializing notifications screen: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = _notificationManager.getFilteredNotifications(
        topic: _selectedTopic,
        priority: _selectedPriority,
        isRead: _showUnreadOnly ? false : null,
        limit: 100,
      );
      
      final stats = _notificationManager.getStatistics();
      
      setState(() {
        _notifications = notifications;
        _stats = stats;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final success = await _notificationManager.markAsRead(notificationId);
    if (success) {
      await _loadNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await _notificationManager.markAllAsRead();
    if (success) {
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final success =
        await _notificationManager.deleteNotification(notificationId);
    if (success) {
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _notificationManager.clearAllNotifications();
      if (success) {
        await _loadNotifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Custom Notifications',
          style: TextStyle(
            color: const Color(0xff212427),
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 22 : 20,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Ionicons.chevron_back,
            color: const Color(0xff212427),
            size: isTablet ? 26 : 24,
          ),
        ),
        actions: [
          if (_stats != null && _stats!.unreadNotifications > 0)
            Container(
              margin: EdgeInsets.only(right: isTablet ? 12 : 8),
              decoration: BoxDecoration(
                color: const Color(0xffF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xffF44336).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: TextButton(
              onPressed: _markAllAsRead,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Mark All Read',
                  style: TextStyle(
                    color: const Color(0xffF44336),
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : 13,
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(
              Ionicons.ellipsis_vertical,
              color: const Color(0xff212427),
              size: isTablet ? 22 : 20,
            ),
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllNotifications();
                  break;
                case 'refresh':
                  _loadNotifications();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Ionicons.refresh_outline),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Ionicons.trash_outline),
                  title: Text('Clear All'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(isTablet)
          : Column(
              children: [
                _buildStatsCard(isTablet),
                _buildFilters(isTablet),
                Expanded(child: _buildNotificationsList(isTablet)),
              ],
            ),
    );
  }

  Widget _buildLoadingState(bool isTablet) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.1),
                    const Color(0xffff5722).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xffF44336)),
                strokeWidth: isTablet ? 4 : 3,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'Loading notifications...',
              style: TextStyle(
                color: const Color(0xff57636C),
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isTablet) {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xffF44336).withOpacity(0.08),
                    const Color(0xffff5722).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF44336).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Ionicons.bar_chart_outline,
                      color: const Color(0xffF44336),
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Text(
                    'Notification Statistics',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff212427),
                      fontSize: isTablet ? 20 : 18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Total',
              _stats!.totalNotifications.toString(),
              Ionicons.notifications_outline,
                  isTablet,
            ),
            _buildStatItem(
              'Unread',
              _stats!.unreadNotifications.toString(),
              Ionicons.mail_unread_outline,
                  isTablet,
            ),
            _buildStatItem(
              'Subscribers',
              _stats!.activeSubscribers.toString(),
              Ionicons.people_outline,
                  isTablet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, bool isTablet) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
      children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: const Color(0xffF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xffF44336),
                size: isTablet ? 24 : 20,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
        Text(
          value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xff212427),
                fontSize: isTablet ? 24 : 20,
              ),
            ),
            SizedBox(height: isTablet ? 4 : 2),
        Text(
          label,
              style: TextStyle(
                color: const Color(0xff57636C),
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xff212427),
                fontSize: isTablet ? 18 : 16,
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Unread Only'),
                  selected: _showUnreadOnly,
                  onSelected: (selected) {
                    setState(() => _showUnreadOnly = selected);
                    _loadNotifications();
                  },
                ),
                DropdownButton<String?>(
                  value: _selectedTopic,
                  hint: const Text('All Topics'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Topics')),
                    ..._notificationManager.getAvailableTopics().map(
                      (topic) => DropdownMenuItem(
                        value: topic,
                        child: Text(topic.split('/').last),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedTopic = value);
                    _loadNotifications();
                  },
                ),
                DropdownButton<AlertPriority?>(
                  value: _selectedPriority,
                  hint: const Text('All Priorities'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Priorities')),
                    ...AlertPriority.values.map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPriority = value);
                    _loadNotifications();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(bool isTablet) {
    if (_notifications.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
              Ionicons.notifications_off_outline,
                  size: isTablet ? 80 : 64,
                  color: const Color(0xff57636C),
                ),
            ),
              SizedBox(height: isTablet ? 24 : 20),
            Text(
              'No notifications found',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff212427),
                  fontSize: isTablet ? 22 : 18,
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 24),
                child: Text(
              'Notifications will appear here when they are received',
                  style: TextStyle(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 16 : 14,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
                ),
            ),
          ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification, isTablet);
      },
    );
  }

  Widget _buildNotificationCard(
      NotificationMessage notification, bool isTablet) {
    final priority = notification.priorityEnum;
    final priorityColor = Color(
        int.parse(priority.colorHex.substring(1), radix: 16) + 0xFF000000);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: notification.isRead
            ? null
            : Border.all(
                color: const Color(0xffF44336).withOpacity(0.2),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!notification.isRead) {
              _markAsRead(notification.id);
            }
            _showNotificationDetails(notification);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTopicIcon(notification.topic),
                    color: priorityColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                          color: const Color(0xff212427),
                          fontSize: isTablet ? 16 : 15,
                        ),
                      ),
                      SizedBox(height: isTablet ? 8 : 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: const Color(0xff57636C),
                          fontSize: isTablet ? 14 : 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isTablet ? 12 : 8),
                      Row(
                        children: [
                          Icon(
                            Ionicons.time_outline,
                            size: isTablet ? 14 : 12,
                            color: const Color(0xff57636C),
                          ),
                          SizedBox(width: isTablet ? 6 : 4),
                          Text(
                            notification.formattedTimestamp,
                            style: TextStyle(
                              color: const Color(0xff57636C),
                              fontSize: isTablet ? 12 : 11,
                            ),
                          ),
                          SizedBox(width: isTablet ? 16 : 12),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 8 : 6,
                              vertical: isTablet ? 4 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority.displayName,
                    style: TextStyle(
                                fontSize: isTablet ? 11 : 10,
                      color: priorityColor,
                                fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                          if (!notification.isRead) ...[
                            const Spacer(),
                            Container(
                              width: isTablet ? 8 : 6,
                              height: isTablet ? 8 : 6,
                              decoration: const BoxDecoration(
                                color: Color(0xffF44336),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
              ],
            ),
          ],
        ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Ionicons.ellipsis_vertical,
                    color: const Color(0xff57636C),
                    size: isTablet ? 20 : 18,
                  ),
          onSelected: (value) {
            switch (value) {
              case 'mark_read':
                _markAsRead(notification.id);
                break;
              case 'delete':
                _deleteNotification(notification.id);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!notification.isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: ListTile(
                  leading: Icon(Ionicons.checkmark_outline),
                  title: Text('Mark as Read'),
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Ionicons.trash_outline),
                title: Text('Delete'),
              ),
            ),
          ],
        ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTopicIcon(String topic) {
    if (topic.contains('data-anomaly')) return Ionicons.warning_outline;
    if (topic.contains('search-error')) return Ionicons.search_outline;
    if (topic.contains('api-error')) return Ionicons.cloud_offline_outline;
    if (topic.contains('health-check')) return Ionicons.pulse_outline;
    return Ionicons.notifications_outline;
  }

  void _showNotificationDetails(NotificationMessage notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification.message),
              const SizedBox(height: 16),
              Text(
                'Details:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification.data.toString(),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
