import 'package:flutter/material.dart';

/// Voice/video call UI — Phase 2 (LiveKit).
class CallScreen extends StatelessWidget {
  const CallScreen({super.key, required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Call · $roomName')),
      body: const Center(
        child: Text('LiveKit call screen — Phase 2'),
      ),
    );
  }
}
