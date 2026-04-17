import 'package:flutter/material.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';
import 'package:flutter_onegate/utils/network_log/models/network_log.dart';
import 'package:flutter_onegate/utils/network_log/services/network_log_service.dart';
import 'package:flutter_onegate/utils/network_log/ui/network_log_screen.dart';

/// A floating overlay that displays the latest network logs
class NetworkLogOverlay extends StatefulWidget {
  final Widget child;

  const NetworkLogOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<NetworkLogOverlay> createState() => _NetworkLogOverlayState();
}

class _NetworkLogOverlayState extends State<NetworkLogOverlay>
    with SingleTickerProviderStateMixin {
  final NetworkLogService _logService = NetworkLogService();
  bool _isExpanded = false;
  bool _isMinimized = true; // Start completely minimized (no floating button)
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  static const double _collapsedHeight = 40.0;
  static const double _expandedHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _heightAnimation = Tween<double>(
      begin: _collapsedHeight,
      end: _expandedHeight,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _minimize() {
    setState(() {
      _isMinimized = true;
      _isExpanded = false;
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (!_isMinimized) // Only show when not minimized
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _heightAnimation,
              builder: (context, child) {
                return Container(
                  height: _heightAnimation.value,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(204), // 0.8 * 255 = 204
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: _buildLogList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        // No floating button - we'll use the bug report icon in the app bar instead
      ],
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        height: _collapsedHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(204), // 0.8 * 255 = 204
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bug_report,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('Network Logs'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<List<NetworkLog>>(
              valueListenable: _logService.logs,
              builder: (context, logs, _) {
                return Text(
                  context
                      .tr('{count} logs', params: {'count': '${logs.length}'}),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NetworkLogScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _toggleExpanded,
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _minimize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList() {
    return ValueListenableBuilder<List<NetworkLog>>(
      valueListenable: _logService.logs,
      builder: (context, logs, _) {
        if (logs.isEmpty) {
          return Center(
            child: Text(
              context.tr('No network logs yet'),
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount:
              logs.length > 5 ? 5 : logs.length, // Show only the latest 5 logs
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              dense: true,
              title: Text(
                '${log.method} ${log.url.split('/').last}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                log.statusCode != null
                    ? context.tr('Status: {status} ({duration})', params: {
                        'status': '${log.statusCode}',
                        'duration': log.formattedDuration,
                      })
                    : context.tr('Error: {error}', params: {
                        'error': log.error?.split('\n').first ??
                            context.tr('Unknown'),
                      }),
                style: TextStyle(
                  color:
                      Color(log.statusColor).withAlpha(204), // 0.8 * 255 = 204
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NetworkLogScreen(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
