import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CustomMediaCacheManager {
  static const key = 'customMediaCacheData';
  static CacheManager? _instance;

  static CacheManager getInstance() {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  static Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();

      // flutter_cache_manager typically stores files in a directory named after the key.
      // On some platforms/versions, it might be inside 'libCachedImageData' or 'flutter_cache_manager'.
      final possiblePaths = {
        p.join(tempDir.path, key),
        p.join(tempDir.path, 'libCachedImageData', key),
        p.join(tempDir.path, 'flutter_cache_manager', key),
      };

      int totalSize = 0;
      final processedFiles = <String>{};

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (var entity
              in dir.list(recursive: true, followLinks: false)) {
            if (entity is File && !processedFiles.contains(entity.path)) {
              totalSize += await entity.length();
              processedFiles.add(entity.path);
            }
          }
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final possiblePaths = {
        p.join(tempDir.path, key),
        p.join(tempDir.path, 'libCachedImageData', key),
        p.join(tempDir.path, 'flutter_cache_manager', key),
      };

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }

      // Also empty the manager instance
      await getInstance().emptyCache();
    } catch (e) {
      debugPrint('Error clearing physical cache: $e');
    }
  }
}
