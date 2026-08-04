import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Thin wrapper around [livekit_client] Room.
///
/// Token + URL come from POST /livekit/token (app JWT session reused).
class LivekitService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Room? get room => _room;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  /// Room naming (DESIGN §6):
  /// - group / chat-tied: `room_{roomId}`
  /// - 1:1 DM: `dm_{minUserId}_{maxUserId}`
  static String chatCallRoom(int roomId) => 'room_$roomId';

  static String dmCallRoom(int userA, int userB) {
    final a = userA < userB ? userA : userB;
    final b = userA < userB ? userB : userA;
    return 'dm_${a}_$b';
  }

  Future<Room> connect({
    required String url,
    required String token, {
    bool enableCamera = true,
    bool enableMicrophone = true,
    void Function(RoomEvent event)? onEvent,
  }) async {
    await disconnect();

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    _listener = room.createListener();
    if (onEvent != null) {
      _listener!.on<RoomEvent>(onEvent);
    }

    await room.prepareConnection(url, token);
    await room.connect(url, token);

    final local = room.localParticipant;
    if (local != null) {
      try {
        await local.setMicrophoneEnabled(enableMicrophone);
      } catch (e) {
        debugPrint('LiveKit mic enable failed: $e');
      }
      if (enableCamera) {
        try {
          await local.setCameraEnabled(true);
        } catch (e) {
          // Common on simulators / missing camera permission
          debugPrint('LiveKit camera enable failed: $e');
        }
      }
    }

    _room = room;
    return room;
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  Future<void> disconnect() async {
    await _listener?.dispose();
    _listener = null;
    final room = _room;
    _room = null;
    if (room != null) {
      await room.disconnect();
      await room.dispose();
    }
  }
}
