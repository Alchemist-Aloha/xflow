import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/entities.dart';
import '../../core/models/tweet.dart';
import '../../core/database/repository.dart';

abstract class MediaRepository {
  Future<List<Tweet>> getUserCachedMedia(String userHandle, int limit);
  Future<void> insertCachedMedia(List<Tweet> tweets);
}

final mediaRepositoryProvider =
    Provider<MediaRepository>((ref) => SqlMediaRepository());

class SqlMediaRepository implements MediaRepository {
  @override
  Future<List<Tweet>> getUserCachedMedia(String userHandle, int limit) {
    return Repository.getUserCachedMedia(userHandle, limit);
  }

  @override
  Future<void> insertCachedMedia(List<Tweet> tweets) {
    return Repository.insertCachedMedia(tweets);
  }
}
