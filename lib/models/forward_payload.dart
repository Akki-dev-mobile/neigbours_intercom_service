class ForwardPayload {
  final String messageId;
  final String text;
  final bool isImage;
  final bool isDocument;
  final bool isAudio;
  final bool isVideo;
  final String? imageUrl;
  final String? documentUrl;
  final String? documentName;
  final String? documentType;
  final String? audioUrl;
  final Duration? audioDuration;
  final String? videoUrl;
  final String? videoThumbnail;

  const ForwardPayload({
    required this.messageId,
    required this.text,
    this.isImage = false,
    this.isDocument = false,
    this.isAudio = false,
    this.isVideo = false,
    this.imageUrl,
    this.documentUrl,
    this.documentName,
    this.documentType,
    this.audioUrl,
    this.audioDuration,
    this.videoUrl,
    this.videoThumbnail,
  });
}
