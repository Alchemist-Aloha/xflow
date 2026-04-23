import 'dart:io';
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
      final cacheDir = Directory(p.join(tempDir.path, key));
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (var file in cacheDir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> clearCache() async {
    await getInstance().emptyCache();
  }
}
