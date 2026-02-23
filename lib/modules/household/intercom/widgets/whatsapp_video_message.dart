import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// WhatsApp-style video message widget
/// Displays video with thumbnail, play button overlay, and duration badge
class WhatsAppVideoMessage extends StatefulWidget {
  final File? videoFile;
  final String? videoUrl;
  final String? thumbnailUrl;
  final Duration? duration;
  final bool isFromMe;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final bool isUploading;
  final double? uploadProgress;
  final bool isDownloading;
  final double? downloadProgress;

  const WhatsAppVideoMessage({
    Key? key,
    this.videoFile,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    required this.isFromMe,
    required this.onTap,
    this.onDownload,
    this.isUploading = false,
    this.uploadProgress,
    this.isDownloading = false,
    this.downloadProgress,
  }) : super(key: key);

  @override
  State<WhatsAppVideoMessage> createState() => _WhatsAppVideoMessageState();
}

class _WhatsAppVideoMessageState extends State<WhatsAppVideoMessage> {
  VideoPlayerController? _thumbnailController;
  bool _isThumbnailLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(WhatsAppVideoMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload thumbnail if video file or URL changed
    if (oldWidget.videoFile != widget.videoFile ||
        oldWidget.videoUrl != widget.videoUrl) {
      _thumbnailController?.dispose();
      _thumbnailController = null;
      _isThumbnailLoaded = false;
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    // Try local file first
    if (widget.videoFile != null && await widget.videoFile!.exists()) {
      try {
        _thumbnailController?.dispose();
        _thumbnailController = VideoPlayerController.file(widget.videoFile!);
        await _thumbnailController!.initialize();
        // Seek to middle frame for better thumbnail
        final duration = _thumbnailController!.value.duration;
        if (duration.inMilliseconds > 0) {
          await _thumbnailController!
              .seekTo(Duration(milliseconds: duration.inMilliseconds ~/ 2));
          await _thumbnailController!.pause();
        }
        if (mounted) {
          setState(() {
            _isThumbnailLoaded = true;
          });
        }
      } catch (e) {
        // If thumbnail generation fails, use placeholder
        _thumbnailController?.dispose();
        _thumbnailController = null;
        if (mounted) {
          setState(() {
            _isThumbnailLoaded = false;
          });
        }
      }
    } else if (widget.videoUrl != null &&
        widget.videoUrl!.isNotEmpty &&
        widget.thumbnailUrl == null) {
      // For remote videos without thumbnail, we'll use placeholder
      // In future, could generate thumbnail from remote URL
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _thumbnailController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          maxHeight: 220,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail or placeholder
              _buildThumbnail(),

              // Play button overlay
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              // Duration badge (bottom right)
              if (widget.duration != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(widget.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // Upload progress overlay (like WhatsApp)
              if (widget.isUploading && widget.uploadProgress != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: widget.uploadProgress,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${((widget.uploadProgress ?? 0) * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Download progress overlay (like WhatsApp)
              if (widget.isDownloading && widget.downloadProgress != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: widget.downloadProgress,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${((widget.downloadProgress ?? 0) * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Download button (show when video is not downloaded and not uploading/downloading)
              // Show download icon if: has videoUrl but no videoFile, not from me, not uploading, not downloading
              if (widget.onDownload != null &&
                  !widget.isFromMe &&
                  !widget.isUploading &&
                  !widget.isDownloading &&
                  widget.videoUrl != null &&
                  widget.videoUrl!.isNotEmpty &&
                  widget.videoFile == null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      widget.onDownload?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 18,
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

  Widget _buildThumbnail() {
    // If we have a local video file and thumbnail is loaded
    if (widget.videoFile != null &&
        _thumbnailController != null &&
        _isThumbnailLoaded) {
      return AspectRatio(
        aspectRatio: _thumbnailController!.value.aspectRatio,
        child: VideoPlayer(_thumbnailController!),
      );
    }

    // If we have a remote thumbnail URL
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    // If we have a remote video URL but no thumbnail, try to show a placeholder
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      return _buildPlaceholder();
    }

    // Default placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}
