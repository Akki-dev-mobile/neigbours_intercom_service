import 'dart:async';
import 'package:flutter/material.dart';
import 'tab_constants.dart';
import '../../../../core/services/request_scheduler.dart';

/// Cancellation token for tab operations
///
/// Used to cancel delayed operations and in-flight requests when tab becomes inactive
class TabCancellationToken {
  final int generation;
  bool _isCancelled = false;

  TabCancellationToken(this.generation);

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  /// Check if this token is still valid for the current generation
  bool isValid(int currentGeneration) {
    return !_isCancelled && generation == currentGeneration;
  }
}

/// Request lock to prevent concurrent API calls
///
/// Ensures only one request is in-flight at a time per tab
class TabRequestLock {
  bool _isLocked = false;
  TabCancellationToken? _currentToken;

  /// Try to acquire the lock
  /// Returns a cancellation token if successful, null if already locked
  TabCancellationToken? tryAcquire(int generation) {
    if (_isLocked) {
      return null;
    }
    _isLocked = true;
    _currentToken = TabCancellationToken(generation);
    return _currentToken;
  }

  /// Release the lock
  void release() {
    _isLocked = false;
    _currentToken?.cancel();
    _currentToken = null;
  }

  /// Check if lock is currently held
  bool get isLocked => _isLocked;

  /// Cancel current operation if it matches the generation
  void cancelIfGeneration(int generation) {
    if (_currentToken?.generation == generation) {
      _currentToken?.cancel();
      release();
    }
  }
}

/// Centralized tab lifecycle controller
///
/// Handles:
/// - Active/inactive transitions
/// - Generation tracking (for cancellation)
/// - Debounce window management
/// - Request locking
///
/// This ensures deterministic, race-condition-free tab behavior.
class TabLifecycleController {
  final int tabIndex;
  final ValueNotifier<int> activeTabNotifier;

  // Generation counter - increments on each activation
  // Used to invalidate stale delayed operations
  int _generation = 0;

  // Request lock to prevent concurrent API calls
  final TabRequestLock _requestLock = TabRequestLock();

  // Debounce tracking
  DateTime? _lastLoadTime;
  Timer? _debounceTimer;

  // Active state tracking
  bool _isActive = false;
  VoidCallback? _onActiveCallback;
  VoidCallback? _onInactiveCallback;

  TabLifecycleController({
    required this.tabIndex,
    required this.activeTabNotifier,
  }) {
    activeTabNotifier.addListener(_onTabNotifierChanged);
    _isActive = activeTabNotifier.value == tabIndex;
  }

  /// Current generation ID
  int get generation => _generation;

  /// Whether this tab is currently active
  bool get isActive => _isActive;

  /// Whether a request is currently in-flight
  bool get hasInFlightRequest => _requestLock.isLocked;

  /// Handle tab notifier changes
  void _onTabNotifierChanged() {
    final newActiveIndex = activeTabNotifier.value;
    final wasActive = _isActive;
    _isActive = newActiveIndex == tabIndex;

    if (!wasActive && _isActive) {
      // Tab just became active
      _onTabBecameActive();
    } else if (wasActive && !_isActive) {
      // Tab just became inactive
      _onTabBecameInactive();
    }
  }

  /// Handle tab becoming active
  void _onTabBecameActive() {
    // Increment generation to invalidate any pending delayed operations
    _generation++;
    debugPrint(
        '🟢 [TabLifecycleController] Tab $tabIndex became active (generation: $_generation)');

    // Cancel any pending debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // Cancel any in-flight requests from previous generation
    _requestLock.cancelIfGeneration(_generation - 1);

    // Trigger active callback
    _onActiveCallback?.call();
  }

  /// Handle tab becoming inactive
  void _onTabBecameInactive() {
    debugPrint('🔴 [TabLifecycleController] Tab $tabIndex became inactive');

    // Cancel any pending debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // Cancel any in-flight requests
    _requestLock.cancelIfGeneration(_generation);

    // CRITICAL FIX: Cancel all requests for this tab via RequestScheduler
    // This prevents inactive tabs from continuing to make API calls
    final ownerId = 'tab_$tabIndex';
    RequestScheduler().cancelOwnerRequests(ownerId, newGeneration: _generation);
    debugPrint(
        '🛑 [TabLifecycleController] Cancelled all requests for tab $tabIndex via RequestScheduler');

    // Trigger inactive callback
    _onInactiveCallback?.call();
  }

  /// Schedule a cancellable delayed operation
  ///
  /// The callback will only execute if:
  /// - Tab is still active
  /// - Generation matches current generation
  /// - Widget is still mounted
  ///
  /// Returns the cancellation token for the operation
  TabCancellationToken scheduleDelayed({
    required Duration delay,
    required VoidCallback callback,
    required bool Function() mountedCheck,
  }) {
    final token = TabCancellationToken(_generation);
    final scheduledGeneration = _generation;

    Timer(delay, () {
      // Check if operation should still execute
      if (token.isCancelled) {
        debugPrint(
            '⏹️ [TabLifecycleController] Cancelled delayed operation (generation: $scheduledGeneration)');
        return;
      }

      if (!mountedCheck()) {
        debugPrint(
            '⏹️ [TabLifecycleController] Widget not mounted, cancelling delayed operation');
        return;
      }

      if (!_isActive || scheduledGeneration != _generation) {
        debugPrint(
            '⏹️ [TabLifecycleController] Tab no longer active or generation changed, cancelling delayed operation');
        return;
      }

      // Execute callback
      callback();
    });

    return token;
  }

  /// Try to acquire request lock for an API call
  ///
  /// Returns cancellation token if lock acquired, null if already locked
  ///
  /// CRITICAL: This is used for tab-level request locking (prevents duplicate calls within tab)
  /// For global concurrency control, use RequestScheduler.schedule() instead
  TabCancellationToken? tryAcquireRequestLock() {
    final token = _requestLock.tryAcquire(_generation);
    if (token != null) {
      debugPrint(
          '🔒 [TabLifecycleController] Request lock acquired (generation: $_generation)');
    } else {
      debugPrint(
          '⏸️ [TabLifecycleController] Request lock already held, ignoring duplicate request');
    }
    return token;
  }

  /// Get owner ID for RequestScheduler (used for cancellation)
  String get ownerId => 'tab_$tabIndex';

  /// Release request lock
  void releaseRequestLock() {
    _requestLock.release();
    debugPrint('🔓 [TabLifecycleController] Request lock released');
  }

  /// Check if a reload should be triggered based on debounce
  ///
  /// Returns true if reload should happen, false if within debounce window
  bool shouldReload() {
    final now = DateTime.now();
    if (_lastLoadTime == null) {
      return true;
    }
    final timeSinceLastLoad = now.difference(_lastLoadTime!);
    return timeSinceLastLoad > TabConstants.kTabReloadDebounce;
  }

  /// Mark that data was loaded
  void markDataLoaded() {
    _lastLoadTime = DateTime.now();
    debugPrint(
        '✅ [TabLifecycleController] Data loaded marked (generation: $_generation)');
  }

  /// Reset load state (e.g., on company change)
  void resetLoadState() {
    _lastLoadTime = null;
    _generation++; // Invalidate all pending operations
    _requestLock.release(); // Release any held locks
    debugPrint(
        '🔄 [TabLifecycleController] Load state reset (new generation: $_generation)');
  }

  /// Set callback for when tab becomes active
  void setOnActiveCallback(VoidCallback? callback) {
    _onActiveCallback = callback;
  }

  /// Set callback for when tab becomes inactive
  void setOnInactiveCallback(VoidCallback? callback) {
    _onInactiveCallback = callback;
  }

  /// Dispose and clean up
  void dispose() {
    activeTabNotifier.removeListener(_onTabNotifierChanged);
    _debounceTimer?.cancel();
    _requestLock.release();
    _onActiveCallback = null;
    _onInactiveCallback = null;
  }
}
