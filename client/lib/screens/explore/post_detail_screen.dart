import 'package:flutter/material.dart';

import '../../models/post.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post.displayName ?? 'Post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: post.width / post.height,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          Text(post.caption),
          const SizedBox(height: 8),
          Text('${post.likeCount} likes · ${post.commentCount} comments'),
        ],
      ),
    );
  }
}
