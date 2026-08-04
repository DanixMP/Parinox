/// Resolves API-relative media paths (`avatars/...`) against the API host.
class MediaUrl {
  MediaUrl._();

  static String resolve(String apiBase, String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath;
    }
    final base = apiBase.replaceAll(RegExp(r'/$'), '');
    // If API is mounted under /api, media still lives at host /media/
    final host = base.replaceFirst(RegExp(r'/api/?$'), '');
    final path = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    if (path.startsWith('media/')) {
      return '$host/$path';
    }
    return '$host/media/$path';
  }
}
