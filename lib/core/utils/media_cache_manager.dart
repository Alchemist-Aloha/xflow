import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomMediaCacheManager {
  static const key = 'customMediaCacheData';
  static CacheManager? _instance;

  static CacheManager getInstance() {
    if (_instance == null) {
      _instance = CacheManager(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200, // Safe upper bound, actual limit is bytes
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      );
    }
    return _instance!;
  }
}
