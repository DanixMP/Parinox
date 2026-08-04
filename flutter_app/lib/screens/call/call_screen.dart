import 'package:flutter/material.dart';

/// Phase 2 — LiveKit voice/video call UI.
class CallScreen extends StatelessWidget {
  const CallScreen({super.key, required this.roomName});
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Call: $roomName')),
      body: const Center(child: Text('Calls — Phase 2')),
    );
  }
}
