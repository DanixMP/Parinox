import 'package:flutter/widgets.dart';

/// Web / non-IO: treat path as network/blob URL when possible.
Widget chatWallpaperFileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Widget? errorChild,
}) {
  return Image.network(
    path,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, __, ___) => errorChild ?? const SizedBox.expand(),
  );
}

Future<String?> persistPickedWallpaper(String sourcePath, String destPath) async {
  // No local filesystem — keep the picker path (often a blob URL).
  return sourcePath;
}
