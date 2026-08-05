import 'dart:io';

import 'package:flutter/widgets.dart';

Widget chatWallpaperFileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Widget? errorChild,
}) {
  return Image.file(
    File(path),
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, __, ___) => errorChild ?? const SizedBox.expand(),
  );
}

Future<String?> persistPickedWallpaper(String sourcePath, String destPath) async {
  final dest = File(destPath);
  await dest.parent.create(recursive: true);
  await File(sourcePath).copy(dest.path);
  return dest.path;
}
