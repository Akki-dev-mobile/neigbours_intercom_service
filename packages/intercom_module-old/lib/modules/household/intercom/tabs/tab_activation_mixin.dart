import 'package:flutter/material.dart';
import 'tab_constants.dart';
import 'tab_lifecycle_controller.dart';

/// Mixin providing race-condition-free tab activation and data loading logic
/// 
/// Uses TabLifecycleController for deterministic, cancellable operations.
/// 
/// Key features:
/// - Generation-based cancellation (prevents stale delayed operations)
/// - Request locking (prevents concurrent API calls)
/// - Immediate cached data rendering (no waiting for network)
/// - Debounce-aware reloads
/// 
/// Usage:
/// ```dart
/// class _MyTabState extends State<MyTab> with TabActivationMixin {
///   @override
///   void initState() {
///     super.initState();
///     initializeTabActivation();
///   }
///   
///   @override
///   void onTabBecameActive({required bool shouldFetchFromNetwork}) {
///     // First: Render cached data immediately (if exists)
///     _renderCachedDataIfAvailable();
///     
///     // Then: Fetch from network if needed
///     if (shouldFetchFromNetwork) {
///       _fetchFromNetwork();
///     }
///   }
/// }
/// ```
mixin TabActivationMixin<T extends StatefulWidget> on State<T> {
  /// ValueNotifier that tracks which tab is currently active
  /// Must be provided by the widget
  ValueNotifier<int>? get activeTabNotifier;

  /// Index of this tab (0, 1, 2, etc.)
  /// Must be provided by the widget
  int? get tabIndex;

  /// Tab lifecycle controller (created during initialization)
  TabLifecycleController? _lifecycleController;

  /// Whether a data load is currently in progress
  /// Must be implemented by the widget to prevent duplicate loads
  bool get isLoading;

  /// Get the lifecycle controller (throws if not initialized)
  TabLifecycleController get lifecycleController {
    if (_lifecycleController == null) {
      throw StateError('TabActivationMixin not initialized. Call initializeTabActivation() first.');
    }
    return _lifecycleController!;
  }

  /// Initialize tab activation with lifecycle controller
  /// 
  /// Call this in initState() after setting up other state
  void initializeTabActivation() {
    if (activeTabNotifier != null && tabIndex != null) {
      _lifecycleController = TabLifecycleController(
        tabIndex: tabIndex!,
        activeTabNotifier: activeTabNotifier!,
      );

      // Set up callbacks
      _lifecycleController!.setOnActiveCallback(() {
        _handleTabBecameActive();
      });

      // Check if tab is already active and trigger initial load
      if (activeTabNotifier!.value == tabIndex) {
        // Schedule initial load with delay
        _lifecycleController!.scheduleDelayed(
          delay: TabConstants.kTabActiveInitDelay,
          callback: () {
            _handleTabBecameActive();
          },
          mountedCheck: () => mounted,
        );
      }
    } else {
      // Fallback: No ValueNotifier - load immediately (backward compatibility)
      if (!isLoading) {
        onTabBecameActive(shouldFetchFromNetwork: true);
      }
    }
  }

  /// Handle tab becoming active (internal)
  void _handleTabBecameActive() {
    if (!mounted || _lifecycleController == null) return;

    // Check if we should fetch from network (debounce check)
    final shouldFetch = _lifecycleController!.shouldReload();

    // Always call onTabBecameActive - it should render cached data immediately
    // and optionally fetch from network
    onTabBecameActive(shouldFetchFromNetwork: shouldFetch);
  }

  /// Called when tab becomes active
  /// 
  /// Override this method to implement your data loading logic.
  /// 
  /// IMPORTANT: This method MUST:
  /// 1. Render cached data immediately (if available) - DO NOT wait for network
  /// 2. Optionally fetch from network if shouldFetchFromNetwork is true
  /// 
  /// This ensures UI is never empty when cached data exists.
  /// 
  /// Parameters:
  /// - [shouldFetchFromNetwork]: true if network fetch should happen (respects debounce)
  void onTabBecameActive({required bool shouldFetchFromNetwork}) {
    // Override in implementing class
  }

  /// Try to acquire request lock for an API call
  /// 
  /// Returns cancellation token if lock acquired, null if already locked
  /// 
  /// Usage:
  /// ```dart
  /// final token = tryAcquireRequestLock();
  /// if (token == null) {
  ///   return; // Request already in-flight, ignore
  /// }
  /// 
  /// try {
  ///   // Make API call
  ///   final data = await fetchData();
  ///   
  ///   // Check if still valid before updating state
  ///   if (!token.isValid(lifecycleController.generation)) {
  ///     return; // Tab became inactive, discard result
  ///   }
  ///   
  ///   // Update state
  ///   setState(() { ... });
  /// } finally {
  ///   releaseRequestLock();
  /// }
  /// ```
  TabCancellationToken? tryAcquireRequestLock() {
    return _lifecycleController?.tryAcquireRequestLock();
  }

  /// Release request lock
  void releaseRequestLock() {
    _lifecycleController?.releaseRequestLock();
  }

  /// Mark that data has been successfully loaded
  /// 
  /// Call this after a successful data load to update debounce tracking
  void markDataLoaded() {
    _lifecycleController?.markDataLoaded();
  }

  /// Reset load state (e.g., on company change)
  /// 
  /// Call this when data should be considered stale and needs reload
  /// This will cancel all pending operations and reset debounce
  void resetLoadState() {
    _lifecycleController?.resetLoadState();
  }

  /// Schedule a cancellable delayed operation
  /// 
  /// The callback will only execute if tab is still active and generation matches
  TabCancellationToken scheduleDelayed({
    required Duration delay,
    required VoidCallback callback,
  }) {
    if (_lifecycleController == null) {
      throw StateError('TabActivationMixin not initialized');
    }
    return _lifecycleController!.scheduleDelayed(
      delay: delay,
      callback: callback,
      mountedCheck: () => mounted,
    );
  }

  /// Clean up tab activation listener
  /// 
  /// Call this in dispose()
  void disposeTabActivation() {
    _lifecycleController?.dispose();
    _lifecycleController = null;
  }
}
