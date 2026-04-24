class Tweet {
  final String id;
  final String text;
  final String userHandle;
  final String? userAvatarUrl;
  final List<String> mediaUrls;
  final String? thumbnailUrl;
  final bool isVideo;
  final DateTime? createdAt;
  final String? source; // "API" or "Cache" or other metadata

  Tweet({
    required this.id,
    required this.text,
    required this.userHandle,
    this.userAvatarUrl,
    required this.mediaUrls,
    this.thumbnailUrl,
    this.isVideo = false,
    this.createdAt,
    this.source,
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
    List<String>? mediaUrls,
    String? thumbnailUrl,
    bool? isVideo,
    DateTime? createdAt,
    String? source,
  }) {
    return Tweet(
      id: id ?? this.id,
      text: text ?? this.text,
      userHandle: userHandle ?? this.userHandle,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isVideo: isVideo ?? this.isVideo,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }
}

