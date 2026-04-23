class Tweet {
  final String id;
  final String text;
  final String userHandle;
  final String? userAvatarUrl;
  final List<String> mediaUrls;
  final String? thumbnailUrl;
  final bool isVideo;
  final DateTime? createdAt;

  Tweet({
    required this.id,
    required this.text,
    required this.userHandle,
    this.userAvatarUrl,
    required this.mediaUrls,
    this.thumbnailUrl,
    this.isVideo = false,
    this.createdAt,
  });

  String? get userAvatarUrlHighRes {
    if (userAvatarUrl == null) return null;
    return userAvatarUrl!.replaceAll('_normal', '');
  }
}
