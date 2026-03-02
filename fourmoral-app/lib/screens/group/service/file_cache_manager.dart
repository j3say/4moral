import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FileCacheManager {
  static Future<File> getCacheFile(String fileName) async {
    final cacheDir = await getTemporaryDirectory();
    return File('${cacheDir.path}/$fileName');
  }

  static Future<bool> isFileCached(String fileName) async {
    final file = await getCacheFile(fileName);
    return await file.exists();
  }

  static Future<File> saveToCache(String fileName, Uint8List bytes) async {
    final file = await getCacheFile(fileName);
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<Uint8List?> getFromCache(String fileName) async {
    if (!await isFileCached(fileName)) return null;
    final file = await getCacheFile(fileName);
    return await file.readAsBytes();
  }

  static Future<void> clearCache() async {
    final cacheDir = await getTemporaryDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
