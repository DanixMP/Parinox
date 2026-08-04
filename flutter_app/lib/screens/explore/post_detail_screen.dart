import 'package:flutter/material.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId});
  final int postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Center(child: Text('Post $postId — Phase 4')),
    );
  }
}
