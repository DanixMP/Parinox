import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../providers/auth_provider.dart';
import '../../services/livekit_service.dart';
import '../../widgets/island_back_button.dart';

/// Voice/video call UI — Phase 2.
///
/// Fetches a LiveKit token from the backend, connects, and shows local + remote
/// participants with mute / camera / hang-up controls.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.livekitRoom,
    this.title,
    this.video = true,
  });

  /// LiveKit room name (`room_{id}` or `dm_{a}_{b}`).
  final String livekitRoom;
  final String? title;
  final bool video;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _livekit = LivekitService();
  String? _error;
  bool _connecting = true;
  bool _micOn = true;
  bool _camOn = true;
  int _participantTick = 0;

  @override
  void initState() {
    super.initState();
    _camOn = widget.video;
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final creds = await api.livekitToken(widget.livekitRoom);
      final url = creds['url'] as String;
      final token = creds['token'] as String;

      await _livekit.connect(
        url: url,
        token: token,
        enableCamera: widget.video,
        enableMicrophone: true,
        onEvent: (_) {
          if (mounted) setState(() => _participantTick++);
        },
      );
      if (mounted) setState(() => _connecting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _hangUp() async {
    await _livekit.disconnect();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _toggleMic() async {
    final next = !_micOn;
    await _livekit.setMicrophoneEnabled(next);
    if (mounted) setState(() => _micOn = next);
  }

  Future<void> _toggleCam() async {
    final next = !_camOn;
    await _livekit.setCameraEnabled(next);
    if (mounted) setState(() => _camOn = next);
  }

  @override
  void dispose() {
    _livekit.disconnect();
    super.dispose();
  }

  List<Participant> get _participants {
    final room = _livekit.room;
    if (room == null) return const [];
    final list = <Participant>[];
    final local = room.localParticipant;
    if (local != null) list.add(local);
    list.addAll(room.remoteParticipants.values);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // Touch tick so participant list rebuilds on RoomEvents
    // ignore: unused_local_variable
    final _ = _participantTick;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1514),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IslandBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        leadingWidth: 60,
        automaticallyImplyLeading: false,
        title: Text(widget.title ?? widget.livekitRoom),
        actions: [
          if (!_connecting && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_participants.length} in call',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _connecting || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundControl(
                      icon: _micOn ? Icons.mic : Icons.mic_off,
                      label: _micOn ? 'Mute' : 'Unmute',
                      onPressed: _toggleMic,
                    ),
                    if (widget.video)
                      _RoundControl(
                        icon: _camOn ? Icons.videocam : Icons.videocam_off,
                        label: _camOn ? 'Camera' : 'Cam off',
                        onPressed: _toggleCam,
                      ),
                    _RoundControl(
                      icon: Icons.call_end,
                      label: 'Leave',
                      color: const Color(0xFFC62828),
                      onPressed: _hangUp,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Joining call…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not join call',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _join, child: const Text('Retry')),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    final participants = _participants;
    if (participants.isEmpty) {
      return const Center(
        child: Text('Waiting for others…', style: TextStyle(color: Colors.white70)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: participants.length == 1 ? 0.75 : 0.7,
      ),
      itemCount: participants.length,
      itemBuilder: (context, i) => _ParticipantTile(participant: participants[i]),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final Participant participant;

  VideoTrack? get _videoTrack {
    for (final pub in participant.videoTrackPublications) {
      if (!pub.isScreenShare && pub.track != null && !pub.muted) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  bool get _micMuted {
    final pubs = participant.audioTrackPublications;
    if (pubs.isEmpty) return true;
    return pubs.first.muted;
  }

  @override
  Widget build(BuildContext context) {
    final video = _videoTrack;
    final name = participant.name.isNotEmpty ? participant.name : participant.identity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF1A2422),
            child: video != null
                ? VideoTrackRenderer(
                    video,
                    fit: VideoViewFit.cover,
                  )
                : Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF2A3D38),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, color: Colors.white),
                      ),
                    ),
                  ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                if (_micMuted)
                  const Icon(Icons.mic_off, size: 14, color: Colors.white70),
                if (_micMuted) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color ?? const Color(0xFF2A3D38),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
