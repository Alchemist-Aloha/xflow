class Tweet {
  final String id;
  final String text;
  final String userHandle;
  final String? userAvatarUrl;
  final String? mediaKey;
  final List<String> mediaUrls;
  final String? thumbnailUrl;
  final bool isVideo;
  final DateTime? createdAt;
  final String? source; // "API" or "Cache" or other metadata
  final bool isLiked;
  final int favoriteCount;
  final int replyCount;

  Tweet({
    required this.id,
    required this.text,
    required this.userHandle,
    this.userAvatarUrl,
    this.mediaKey,
    required this.mediaUrls,
    this.thumbnailUrl,
    this.isVideo = false,
    this.createdAt,
    this.source,
    this.isLiked = false,
    this.favoriteCount = 0,
    this.replyCount = 0,
  });

  String? get userAvatarUrlHighRes {
    if (userAvatarUrl == null) return null;
    return userAvatarUrl!.replaceAll('_normal', '');
  }

  Tweet copyWith({
    String? id,
    String? text,
    String? userHandle,
    String? userAvatarUrl,
    String? mediaKey,
    List<String>? mediaUrls,
    String? thumbnailUrl,
    bool? isVideo,
    DateTime? createdAt,
    String? source,
    bool? isLiked,
    int? favoriteCount,
    int? replyCount,
  }) {
    return Tweet(
      id: id ?? this.id,
      text: text ?? this.text,
      userHandle: userHandle ?? this.userHandle,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      mediaKey: mediaKey ?? this.mediaKey,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isVideo: isVideo ?? this.isVideo,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      isLiked: isLiked ?? this.isLiked,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      replyCount: replyCount ?? this.replyCount,
    );
  }
}
