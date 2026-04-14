import 'dart:async';
import 'dart:developer';
import 'dart:collection';

/// Request priority levels
enum RequestPriority {
  userAction, // User-triggered (tap chat, open screen) - highest priority
  visibleTab, // Visible tab initial list - high priority
  background, // Background prefetch (last message preview, member list) - low priority
}

/// Request feature category for per-feature concurrency limits
enum RequestFeature {
  chat, // Chat-related: /rooms, /rooms/{id}/info, /rooms/{id}/messages
  committee, // Committee members
  residents, // Residents/Neighbors lists
  other, // Other requests
}

/// Request metadata for scheduling
class ScheduledRequest {
  final String requestKey; // method + path + query + bodyHash + company_id
  final RequestPriority priority;
  final RequestFeature feature;
  final Future<dynamic> Function() execute;
  final String? ownerId; // Tab/screen identifier for cancellation
  final int? generation; // Generation token for cancellation
  final Completer<dynamic> completer;
  final DateTime timestamp;

  ScheduledRequest({
    required this.requestKey,
    required this.priority,
    required this.feature,
    required this.execute,
    this.ownerId,
    this.generation,
    required this.completer,
  }) : timestamp = DateTime.now();
}

/// Global request scheduler with concurrency limits and priority queue
///
/// Features:
/// - Global concurrency limit (max 4 concurrent calls total)
/// - Per-feature concurrency limits
/// - Priority queue (user actions > visible tab > background)
/// - Request cancellation for inactive tabs
/// - Request deduplication (in-flight coalescing)
class RequestScheduler {
  static final RequestScheduler _instance = RequestScheduler._internal();
  factory RequestScheduler() => _instance;
  RequestScheduler._internal();

  // Global concurrency limit
  static const int _maxGlobalConcurrency = 4;

  // Per-feature concurrency limits
  static const Map<RequestFeature, int> _featureConcurrencyLimits = {
    RequestFeature.chat: 2,
    RequestFeature.committee: 2,
    RequestFeature.residents: 1,
    RequestFeature.other: 2,
  };

  // Active request counts
  int _globalActiveCount = 0;
  final Map<RequestFeature, int> _featureActiveCounts = {
    RequestFeature.chat: 0,
    RequestFeature.committee: 0,
    RequestFeature.residents: 0,
    RequestFeature.other: 0,
  };

  // Priority queues (separate queues per priority level)
  final Queue<ScheduledRequest> _userActionQueue = Queue();
  final Queue<ScheduledRequest> _visibleTabQueue = Queue();
  final Queue<ScheduledRequest> _backgroundQueue = Queue();

  // In-flight requests (for deduplication)
  final Map<String, Completer<dynamic>> _inFlightRequests = {};

  // Active requests (for cancellation)
  final Map<String, ScheduledRequest> _activeRequests = {};
  final Map<String, Set<String>> _ownerRequests =
      {}; // ownerId -> Set<requestKey>

  /// Schedule a request with priority and feature
  Future<T> schedule<T>({
    required String requestKey,
    required RequestPriority priority,
    required RequestFeature feature,
    required Future<T> Function() execute,
    String? ownerId,
    int? generation,
  }) async {
    // Check for in-flight deduplication
    if (_inFlightRequests.containsKey(requestKey)) {
      log('🔄 [RequestScheduler] Request deduplication: reusing in-flight request: $requestKey');
      return await _inFlightRequests[requestKey]!.future as Future<T>;
    }

    // Create completer for this request
    final completer = Completer<T>();
    _inFlightRequests[requestKey] = completer;

    // Create scheduled request
    final request = ScheduledRequest(
      requestKey: requestKey,
      priority: priority,
      feature: feature,
      execute: execute as Future<dynamic> Function(),
      ownerId: ownerId,
      generation: generation,
      completer: completer,
    );

    // Track owner for cancellation
    if (ownerId != null) {
      _ownerRequests.putIfAbsent(ownerId, () => {}).add(requestKey);
    }

    // Add to appropriate priority queue
    switch (priority) {
      case RequestPriority.userAction:
        _userActionQueue.add(request);
        break;
      case RequestPriority.visibleTab:
        _visibleTabQueue.add(request);
        break;
      case RequestPriority.background:
        _backgroundQueue.add(request);
        break;
    }

    log('📋 [RequestScheduler] Scheduled request: $requestKey (priority: $priority, feature: $feature)');

    // Process queues
    _processQueues();

    // Return future
    try {
      final result = await completer.future;
      // Type is already T from the completer
      return result;
    } finally {
      // Clean up
      _inFlightRequests.remove(requestKey);
      if (ownerId != null) {
        _ownerRequests[ownerId]?.remove(requestKey);
        if (_ownerRequests[ownerId]?.isEmpty ?? false) {
          _ownerRequests.remove(ownerId);
        }
      }
    }
  }

  /// Process priority queues
  void _processQueues() {
    while (_canProcessMore()) {
      ScheduledRequest? request;

      // Priority order: userAction > visibleTab > background
      if (_userActionQueue.isNotEmpty) {
        request = _userActionQueue.removeFirst();
      } else if (_visibleTabQueue.isNotEmpty) {
        request = _visibleTabQueue.removeFirst();
      } else if (_backgroundQueue.isNotEmpty) {
        request = _backgroundQueue.removeFirst();
      }

      if (request == null) break;

      // Check if request was cancelled (generation mismatch)
      if (request.generation != null && request.ownerId != null) {
        // Check generation (would need owner generation tracking - simplified for now)
        // For now, just check if owner is still valid
      }

      // Execute request
      _executeRequest(request);
    }
  }

  /// Check if more requests can be processed
  bool _canProcessMore() {
    if (_globalActiveCount >= _maxGlobalConcurrency) {
      return false;
    }

    // Check if any queue has requests
    if (_userActionQueue.isEmpty &&
        _visibleTabQueue.isEmpty &&
        _backgroundQueue.isEmpty) {
      return false;
    }

    return true;
  }

  /// Execute a request
  void _executeRequest(ScheduledRequest request) async {
    // Check concurrency limits
    if (_globalActiveCount >= _maxGlobalConcurrency) {
      log('⏸️ [RequestScheduler] Global concurrency limit reached, queuing: ${request.requestKey}');
      // Re-queue based on priority
      switch (request.priority) {
        case RequestPriority.userAction:
          _userActionQueue.addFirst(request);
          break;
        case RequestPriority.visibleTab:
          _visibleTabQueue.addFirst(request);
          break;
        case RequestPriority.background:
          _backgroundQueue.addFirst(request);
          break;
      }
      return;
    }

    final featureLimit = _featureConcurrencyLimits[request.feature] ?? 2;
    if (_featureActiveCounts[request.feature]! >= featureLimit) {
      log('⏸️ [RequestScheduler] Feature concurrency limit reached for ${request.feature}, queuing: ${request.requestKey}');
      // Re-queue
      switch (request.priority) {
        case RequestPriority.userAction:
          _userActionQueue.addFirst(request);
          break;
        case RequestPriority.visibleTab:
          _visibleTabQueue.addFirst(request);
          break;
        case RequestPriority.background:
          _backgroundQueue.addFirst(request);
          break;
      }
      return;
    }

    // Increment counters
    _globalActiveCount++;
    _featureActiveCounts[request.feature] =
        _featureActiveCounts[request.feature]! + 1;
    _activeRequests[request.requestKey] = request;

    log('🚀 [RequestScheduler] Executing: ${request.requestKey} (global: $_globalActiveCount/${_maxGlobalConcurrency}, ${request.feature}: ${_featureActiveCounts[request.feature]}/$featureLimit)');

    try {
      final result = await request.execute();

      // Check if request was cancelled
      if (!request.completer.isCompleted) {
        request.completer.complete(result);
      }
    } catch (e) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(e);
      }
    } finally {
      // Decrement counters
      _globalActiveCount--;
      _featureActiveCounts[request.feature] =
          _featureActiveCounts[request.feature]! - 1;
      _activeRequests.remove(request.requestKey);

      log('✅ [RequestScheduler] Completed: ${request.requestKey} (global: $_globalActiveCount/${_maxGlobalConcurrency})');

      // Process next request
      _processQueues();
    }
  }

  /// Cancel all requests for an owner (e.g., inactive tab)
  void cancelOwnerRequests(String ownerId, {int? newGeneration}) {
    final requestKeys = _ownerRequests[ownerId]?.toList() ?? [];
    log('🛑 [RequestScheduler] Cancelling ${requestKeys.length} requests for owner: $ownerId');

    for (final requestKey in requestKeys) {
      // Remove from queues
      _userActionQueue.removeWhere((r) => r.requestKey == requestKey);
      _visibleTabQueue.removeWhere((r) => r.requestKey == requestKey);
      _backgroundQueue.removeWhere((r) => r.requestKey == requestKey);

      // Cancel active request
      final activeRequest = _activeRequests[requestKey];
      if (activeRequest != null) {
        if (!activeRequest.completer.isCompleted) {
          activeRequest.completer.completeError(
            CancellationException(
                'Request cancelled: owner $ownerId became inactive'),
          );
        }
        _activeRequests.remove(requestKey);
        _globalActiveCount--;
        _featureActiveCounts[activeRequest.feature] =
            _featureActiveCounts[activeRequest.feature]! - 1;
      }

      // Remove from in-flight
      _inFlightRequests.remove(requestKey);
    }

    _ownerRequests.remove(ownerId);
    log('✅ [RequestScheduler] Cancelled all requests for owner: $ownerId');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'globalActive': _globalActiveCount,
      'globalLimit': _maxGlobalConcurrency,
      'featureActive': Map.fromEntries(
        _featureActiveCounts.entries
            .map((e) => MapEntry(e.key.toString(), e.value)),
      ),
      'queueSizes': {
        'userAction': _userActionQueue.length,
        'visibleTab': _visibleTabQueue.length,
        'background': _backgroundQueue.length,
      },
      'inFlightCount': _inFlightRequests.length,
      'activeCount': _activeRequests.length,
    };
  }
}

/// Exception for cancelled requests
class CancellationException implements Exception {
  final String message;
  CancellationException(this.message);
  @override
  String toString() => 'CancellationException: $message';
}
