import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

enum MediaType { image, video }

class MediaItem {
  final String path;
  final MediaType type;
  final String? title;

  MediaItem({
    required this.path,
    required this.type,
    this.title,
  });
}

class VideoCarouselItem extends StatefulWidget {
  final MediaItem mediaItem;
  final bool isActive;
  final bool isTablet;
  final VoidCallback? onTap;

  const VideoCarouselItem({
    Key? key,
    required this.mediaItem,
    required this.isActive,
    required this.isTablet,
    this.onTap,
  }) : super(key: key);

  @override
  State<VideoCarouselItem> createState() => _VideoCarouselItemState();
}

class _VideoCarouselItemState extends State<VideoCarouselItem>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.mediaItem.type == MediaType.video) {
      _initializeVideo();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(VideoCarouselItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle video playback based on active state
    if (widget.mediaItem.type == MediaType.video && _videoController != null) {
      if (widget.isActive && !oldWidget.isActive) {
        // Became active - start playing
        _videoController!.play();
      } else if (!widget.isActive && oldWidget.isActive) {
        // Became inactive - pause
        _videoController!.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(widget.mediaItem.path);
      await _videoController!.initialize();

      // Set looping
      await _videoController!.setLooping(true);

      // Start muted
      await _videoController!.setVolume(0.0);

      // Auto-play if this item is active
      if (widget.isActive) {
        await _videoController!.play();
      }

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_videoController == null) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isMuted = !_isMuted;
    });

    await _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: widget.isTablet ? 20 : 16,
        vertical: widget.isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.isTablet ? 28 : 24),
        boxShadow: [
          // Primary shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: widget.isTablet ? 20 : 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // Secondary shadow for softness
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: widget.isTablet ? 10 : 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.isTablet ? 28 : 24),
        child: Stack(
          children: [
            // Media content with aspect ratio container
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black12,
                ),
                child: widget.mediaItem.type == MediaType.video
                    ? _buildVideoContent()
                    : _buildImageContent(),
              ),
            ),

            // Enhanced overlay gradient for better readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 0.7, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),

            // Brand/Logo area (top overlay)
            Positioned(
              top: widget.isTablet ? 24 : 20,
              left: widget.isTablet ? 24 : 20,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isTablet ? 16 : 12,
                  vertical: widget.isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius:
                      BorderRadius.circular(widget.isTablet ? 20 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: widget.isTablet ? 24 : 20,
                      height: widget.isTablet ? 24 : 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffF44336), Color(0xffD32F2F)],
                        ),
                        borderRadius:
                            BorderRadius.circular(widget.isTablet ? 12 : 10),
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: widget.isTablet ? 16 : 14,
                      ),
                    ),
                    SizedBox(width: widget.isTablet ? 8 : 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: widget.isTablet ? 12 : 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xffF44336),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sound toggle button (only for videos) - repositioned
            if (widget.mediaItem.type == MediaType.video && _isVideoInitialized)
              Positioned(
                top: widget.isTablet ? 24 : 20,
                right: widget.isTablet ? 24 : 20,
                child: _buildSoundToggleButton(),
              ),

            // Enhanced title/branding overlay at bottom
            if (widget.mediaItem.title != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(widget.isTablet ? 24 : 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main title
                      Text(
                        widget.mediaItem.title!.toUpperCase(),
                        style: TextStyle(
                          fontSize: widget.isTablet ? 28 : 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: widget.isTablet ? 8 : 6),
                      // Subtitle/tagline
                      Text(
                        'Smart Digital Solutions',
                        style: TextStyle(
                          fontSize: widget.isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: widget.isTablet ? 12 : 8),
                      // CTA button
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isTablet ? 20 : 16,
                          vertical: widget.isTablet ? 10 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffF44336), Color(0xffD32F2F)],
                          ),
                          borderRadius:
                              BorderRadius.circular(widget.isTablet ? 25 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffF44336).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Learn More',
                          style: TextStyle(
                            fontSize: widget.isTablet ? 14 : 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Loading indicator with enhanced styling
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius:
                        BorderRadius.circular(widget.isTablet ? 28 : 24),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(widget.isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                                widget.isTablet ? 16 : 12),
                          ),
                          child: const DashboardLoaderIcon(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xffF44336)),
                          ),
                        ),
                        SizedBox(height: widget.isTablet ? 16 : 12),
                        Text(
                          AppLocalizations.of(context).loading,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Tap detector with ripple effect
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(widget.isTablet ? 28 : 24),
                  onTap: widget.onTap,
                  splashColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(
            Icons.video_library,
            color: Colors.white54,
            size: 48,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }

  Widget _buildImageContent() {
    return Image.network(
      widget.mediaItem.path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black12,
          child: Center(
            child: const DashboardLoaderIcon(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.black12,
          child: const Center(
            child: Icon(
              Icons.error,
              color: Colors.white54,
              size: 48,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundToggleButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(widget.isTablet ? 25 : 20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: widget.isTablet ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.isTablet ? 25 : 20),
          onTap: _toggleMute,
          child: Container(
            padding: EdgeInsets.all(widget.isTablet ? 14 : 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                key: ValueKey(_isMuted),
                color: _isMuted ? Colors.white70 : Colors.white,
                size: widget.isTablet ? 24 : 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
