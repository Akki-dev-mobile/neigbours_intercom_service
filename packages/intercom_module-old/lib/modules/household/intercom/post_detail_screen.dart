import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import 'models/post_model.dart';

import '../../../core/widgets/enhanced_toast.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment() {
    if (_commentController.text.trim().isNotEmpty) {
      setState(() {
        widget.post.commentCount++;
        _commentController.clear();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Comment added')));
    }
  }

  void _toggleLike() {
    setState(() {
      widget.post.toggleLike();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: false,
        title: const Text(
          'Post Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {
              // Share functionality
              EnhancedToast.info(
                context,
                title: 'Share Feature',
                message: 'Share functionality coming soon',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Post content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info and timestamp
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    widget.post.flatNumber,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('•',
                                      style: TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.post.timeAgo,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Post content
                    Text(
                      widget.post.content,
                      style: const TextStyle(fontSize: 16),
                    ),

                    if (widget.post.images.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // Display images
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.post.images.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade200,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  'https://picsum.photos/seed/${widget.post.images[index]}/800/800',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.image_not_supported,
                                          size: 40, color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),

                    // Like and comment counts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton.icon(
                          onPressed: _toggleLike,
                          icon: Icon(
                            widget.post.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.post.isLiked
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                          label: Text(
                            '${widget.post.likeCount} likes',
                            style: TextStyle(
                              color: widget.post.isLiked
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {}, // Already on comment page
                          icon: Icon(Icons.comment_outlined,
                              color: Colors.grey.shade600),
                          label: Text(
                            '${widget.post.commentCount} comments',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),

                    const Divider(),
                    const SizedBox(height: 16),

                    // Comments section header
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sample comments
                    _buildSampleComment(
                      'Rahul Sharma',
                      'This is great information! Thank you for sharing.',
                      '2 hours ago',
                    ),
                    _buildSampleComment(
                      'Priya Patel',
                      'I will definitely attend the meeting.',
                      '1 hour ago',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Comment input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleComment(String name, String comment, String timeAgo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
