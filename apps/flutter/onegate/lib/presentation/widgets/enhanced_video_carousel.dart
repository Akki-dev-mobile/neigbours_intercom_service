import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Enhanced Video Carousel for Ads
///
/// Features:
/// - 4 cyberone videos with autoplay (muted by default)
/// - Per-video sound toggle (speaker icon overlay)
/// - Responsive full-width cards
/// - Smooth swipe transitions
/// - Page indicator dots
/// - No impact on existing dashboard functionality
class EnhancedVideoCarousel extends StatefulWidget {
  const EnhancedVideoCarousel({super.key});

  @override
  State<EnhancedVideoCarousel> createState() => _EnhancedVideoCarouselState();
}

class _EnhancedVideoCarouselState extends State<EnhancedVideoCarousel> {
  late PageController _pageController;
  late List<VideoPlayerController?> _videoControllers;
  int _currentIndex = 0;
  bool _isDisposed = false;
  Timer? _autoAdvanceTimer;

  // Video configurations
  final List<Map<String, String>> _videos = [
    {
      'path': 'assets/onegate/cyberonevideo1.mp4',
    },
    {
      'path': 'assets/onegate/cyberonevideo2.mp4',
    },
    {
      'path': 'assets/onegate/cyberonevideo3.mp4',
    },
    {
      'path': 'assets/onegate/cyberonevideo4.mp4',
    },
  ];

  // Global mute state - all videos share the same mute state
  bool _isGlobalMuted = true;

  // Track completion to prevent multiple triggers
  final Set<int> _completedVideos = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _videoControllers =
        List<VideoPlayerController?>.filled(_videos.length, null);
    _initializeVideos();
  }

  Future<void> _initializeVideos() async {
    for (int i = 0; i < _videos.length; i++) {
      try {
        final controller = VideoPlayerController.asset(_videos[i]['path']!);
        await controller.initialize();

        // Set looping and muted by default
        await controller.setLooping(false); // Don't loop individual videos
        await controller.setVolume(_isGlobalMuted ? 0.0 : 1.0);

        _videoControllers[i] = controller;

        // Add completion listener for auto-advance
        controller.addListener(() {
          final position = controller.value.position;
          final duration = controller.value.duration;

          // Check if video completed (with small buffer for precision)
          if (duration.inMilliseconds > 0 &&
              position >= duration - const Duration(milliseconds: 100)) {
            _onVideoCompleted(i);
          }
        });

        // Auto-play first video
        if (i == 0) {
          await controller.play();
        }

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Error initializing video $i: $e');
      }
    }
  }

  void _onPageChanged(int index) {
    if (_isDisposed) return;

    final oldIndex = _currentIndex;
    _currentIndex = index;

    // Pause previous video
    if (_videoControllers[oldIndex] != null) {
      _videoControllers[oldIndex]!.pause();
    }

    // Play current video
    if (_videoControllers[index] != null) {
      _videoControllers[index]!.play();
    }

    setState(() {});
  }

  void _onVideoCompleted(int completedIndex) {
    if (_isDisposed || !mounted) return;

    // Prevent multiple completion triggers for the same video
    if (_completedVideos.contains(completedIndex)) return;
    _completedVideos.add(completedIndex);

    // Calculate next video index (loops back to 0 after last video)
    final nextIndex = (completedIndex + 1) % _videos.length;

    debugPrint(
        'Video $completedIndex completed, advancing to video $nextIndex');

    // Advance to next video with smooth animation
    _pageController
        .animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    )
        .then((_) {
      // Ensure the new video starts playing after animation completes
      if (!_isDisposed && mounted && _videoControllers[nextIndex] != null) {
        _videoControllers[nextIndex]!.play();
        // Clear completion tracking for the new video
        _completedVideos.remove(nextIndex);
      }
    });
  }

  Future<void> _toggleMute(int index) async {
    if (_videoControllers[index] == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isGlobalMuted = !_isGlobalMuted;
    });

    // Apply global mute state to all videos
    for (int i = 0; i < _videoControllers.length; i++) {
      if (_videoControllers[i] != null) {
        await _videoControllers[i]!.setVolume(_isGlobalMuted ? 0.0 : 1.0);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoAdvanceTimer?.cancel();
    for (final controller in _videoControllers) {
      controller?.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive heights: Mobile 200-220dp, Tablet 280-320dp
    final carouselHeight = isTablet
        ? (screenHeight * 0.3).clamp(280.0, 320.0)
        : (screenHeight * 0.25).clamp(200.0, 220.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Video Carousel
        SizedBox(
          height: carouselHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildVideoCard(index, isTablet);
            },
          ),
        ),

        const SizedBox(height: 16),

        // Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _videos.asMap().entries.map((entry) {
            final i = entry.key;
            final isActive = i == _currentIndex;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: isTablet ? 6 : 4),
              width: isActive ? (isTablet ? 32 : 24) : (isTablet ? 12 : 8),
              height: isTablet ? 12 : 8,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xffF44336), Color(0xffD32F2F)],
                      )
                    : null,
                color: isActive ? null : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(isTablet ? 6 : 4),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVideoCard(int index, bool isTablet) {
    final controller = _videoControllers[index];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: isTablet ? 20 : 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isTablet ? 10 : 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: GestureDetector(
          onTap: () => _toggleMute(index),
          child: Stack(
            children: [
              // Video Player
              Positioned.fill(
                child: controller == null || !controller.value.isInitialized
                    ? Container(
                        color: Colors.black12,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xffF44336),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
