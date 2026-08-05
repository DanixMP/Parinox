/// Resolves API-relative media paths (`avatars/...`) against the API host.
///
/// Authenticated media requires [authToken] (set from [ApiService]) so image
/// widgets can load private `/media` without custom headers.
class MediaUrl {
  MediaUrl._();

  /// JWT used as `access_token` query param for CachedNetworkImage / players.
  static String? authToken;

  static String resolve(String apiBase, String? relativePath, {String? accessToken}) {
    if (relativePath == null || relativePath.isEmpty) return '';
    final base = apiBase.replaceAll(RegExp(r'/$'), '');
    final host = base.replaceFirst(RegExp(r'/api/?$'), '');

    // Block arbitrary remote URLs (media_path IDOR / open redirect style abuse).
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      final uri = Uri.tryParse(relativePath);
      final allowedHost = Uri.tryParse(host)?.host;
      if (uri == null || allowedHost == null || uri.host != allowedHost) {
        return '';
      }
      return relativePath;
    }

    final path = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    final mediaPath = path.startsWith('media/') ? path : 'media/$path';
    var url = '$host/$mediaPath';
    final token = accessToken ?? authToken;
    if (token != null && token.isNotEmpty) {
      url = Uri.parse(url).replace(queryParameters: {
        'access_token': token,
      }).toString();
    }
    return url;
  }
}
