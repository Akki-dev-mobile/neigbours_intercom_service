import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/enhanced_toast.dart';
import '../models/post_model.dart';
import '../post_detail_screen.dart';
import '../create_post_screen.dart';
import '../../../../core/utils/navigation_helper.dart';

class PostsTab extends StatefulWidget {
  const PostsTab({Key? key}) : super(key: key);

  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab> {
  late List<Post> _posts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate loading from backend
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadPosts();
        });
      }
    });
  }

  void _loadPosts() {
    // In a real app, this would be fetched from an API
    _posts = [
      Post(
        id: 'p1',
        userName: 'Priya Sharma',
        userAvatar: 'assets/avatars/user1.png',
        flatNumber: 'A-101',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        content:
            'Just received notice about the upcoming society general meeting. Everyone please mark your calendars for next Sunday!',
        likeCount: 14,
        commentCount: 5,
      ),
      Post(
        id: 'p2',
        userName: 'Rajesh Kumar',
        userAvatar: 'assets/avatars/user2.png',
        flatNumber: 'B-204',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        content:
            'The kids playground equipment has been upgraded. My children are loving the new swings!',
        images: ['assets/images/playground.jpg'],
        likeCount: 28,
        commentCount: 7,
      ),
      Post(
        id: 'p3',
        userName: 'Anita Desai',
        userAvatar: 'assets/avatars/user3.png',
        flatNumber: 'D-303',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        content:
            'Found this beautiful bird on my balcony this morning. Nature is healing! 🦜',
        images: ['assets/images/bird1.jpg', 'assets/images/bird2.jpg'],
        likeCount: 42,
        commentCount: 12,
        isLiked: true,
      ),
      Post(
        id: 'p4',
        userName: 'Society Manager',
        userAvatar: 'assets/avatars/manager.png',
        flatNumber: 'Office',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        content:
            'Important announcement: Water supply will be interrupted tomorrow from 10 AM to 2 PM due to maintenance work. Please store water accordingly.',
        likeCount: 19,
        commentCount: 8,
      ),
      Post(
        id: 'p5',
        userName: 'Vikram Singh',
        userAvatar: 'assets/avatars/user4.png',
        flatNumber: 'C-102',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        content:
            'Successful tree planting drive today! Thanks to everyone who participated. Together we planted 20 new saplings in our society garden.',
        images: [
          'assets/images/planting1.jpg',
          'assets/images/planting2.jpg',
          'assets/images/planting3.jpg'
        ],
        likeCount: 56,
        commentCount: 23,
      ),
    ];
  }

  void _handleLike(Post post) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _posts[index].toggleLike();
      }
    });
  }

  void _navigateToPostDetail(Post post) {
    NavigationHelper.pushRoute(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: AppLoader(
          title: 'Loading Posts',
          subtitle: 'Fetching society posts and updates...',
          icon: Icons.forum_rounded,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Stack(
          children: [
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Header card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF33658A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.forum_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Community Posts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stay updated with the latest news and announcements from your society community.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Posts list
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return _PostCard(
                      post: post,
                      onLike: () => _handleLike(post),
                      onComment: () => _navigateToPostDetail(post),
                      onTap: () => _navigateToPostDetail(post),
                    );
                  },
                ),
              ],
            ),

            // Add Floating Action Button
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  NavigationHelper.pushRoute(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreatePostScreen(),
                    ),
                  ).then((newPost) {
                    if (newPost != null && newPost is Post) {
                      setState(() {
                        _posts.insert(0, newPost);
                      });
                      EnhancedToast.success(
                        context,
                        title: 'Post Published',
                        message: 'Post published successfully!',
                      );
                    }
                  });
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info and timestamp
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              post.flatNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '•',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              post.timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: Colors.grey.shade600,
                    onPressed: () {
                      // Show options menu
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (context) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.report_outlined),
                                title: const Text('Report post'),
                                onTap: () {
                                  Navigator.pop(context);
                                  EnhancedToast.success(
                                    context,
                                    title: 'Post Reported',
                                    message: 'Post reported successfully',
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.share_outlined),
                                title: const Text('Share post'),
                                onTap: () {
                                  Navigator.pop(context);
                                  EnhancedToast.success(
                                    context,
                                    title: 'Post Shared',
                                    message: 'Post shared successfully',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Post content
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(post.content),
              ),

              // Post images (if any)
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildImageGrid(post.images, context),
                const SizedBox(height: 12),
              ],

              // Divider
              const Divider(height: 1),

              // Engagement buttons (like, comment)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: onLike,
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : Colors.grey.shade600,
                      size: 20,
                    ),
                    label: Text(
                      post.likeCount.toString(),
                      style: TextStyle(
                        color: post.isLiked ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onComment,
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    label: Text(
                      post.commentCount.toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images, BuildContext context) {
    if (images.length == 1) {
      // Single image
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            // In a real app, these would be valid URLs
            'https://picsum.photos/seed/${images[0]}/800/800',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.image_not_supported,
                    size: 40, color: Colors.grey),
              );
            },
          ),
        ),
      );
    } else {
      // Multiple images grid
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: images.length == 2 ? 2 : 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length > 6 ? 6 : images.length,
        itemBuilder: (context, index) {
          if (images.length > 6 && index == 5) {
            // Show +X more overlay on the last visible image
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://picsum.photos/seed/${images[index]}/400/400',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.image_not_supported,
                              size: 30, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: Center(
                    child: Text(
                      '+${images.length - 5}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://picsum.photos/seed/${images[index]}/400/400',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image_not_supported,
                        size: 30, color: Colors.grey),
                  );
                },
              ),
            ),
          );
        },
      );
    }
  }
}
