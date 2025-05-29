import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/services/notifications/notification_manager.dart';
import 'package:flutter_onegate/services/notifications/models/notification_models.dart';
import 'package:ionicons/ionicons.dart';

/// Screen for viewing and managing custom notifications
class CustomNotificationsScreen extends StatefulWidget {
  const CustomNotificationsScreen({super.key});

  @override
  State<CustomNotificationsScreen> createState() => _CustomNotificationsScreenState();
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
    final success = await _notificationManager.deleteNotification(notificationId);
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
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Notifications'),
        actions: [
          if (_stats != null && _stats!.unreadNotifications > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark All Read'),
            ),
          PopupMenuButton<String>(
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCard(),
                _buildFilters(),
                Expanded(child: _buildNotificationsList()),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Total',
              _stats!.totalNotifications.toString(),
              Ionicons.notifications_outline,
            ),
            _buildStatItem(
              'Unread',
              _stats!.unreadNotifications.toString(),
              Ionicons.mail_unread_outline,
            ),
            _buildStatItem(
              'Subscribers',
              _stats!.activeSubscribers.toString(),
              Ionicons.people_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
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
                    const DropdownMenuItem(value: null, child: Text('All Topics')),
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
                    const DropdownMenuItem(value: null, child: Text('All Priorities')),
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

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Ionicons.notifications_off_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notifications will appear here when they are received',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationMessage notification) {
    final priority = notification.priorityEnum;
    final priorityColor = Color(int.parse(priority.colorHex.substring(1), radix: 16) + 0xFF000000);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: priorityColor.withOpacity(0.1),
          child: Icon(
            _getTopicIcon(notification.topic),
            color: priorityColor,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Ionicons.time_outline, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  notification.formattedTimestamp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
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
        onTap: () {
          if (!notification.isRead) {
            _markAsRead(notification.id);
          }
          _showNotificationDetails(notification);
        },
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
