/// LiveKit wrapper — Phase 2 wiring.
///
/// Token is minted by POST /livekit/token using the same JWT session.
class LiveKitService {
  Future<Map<String, String>> requestToken({
    required Future<Map<String, dynamic>> Function(String room) fetchToken,
    required String room,
  }) {
    return fetchToken(room).then(
      (data) => {
        'token': data['token'] as String,
        'url': data['url'] as String,
      },
    );
  }
}
