class Tweet {
  final String id;
  final String text;
  final String userHandle;
  final List<String> mediaUrls;
  final bool isVideo;

  Tweet({
    required this.id,
    required this.text,
    required this.userHandle,
    required this.mediaUrls,
    this.isVideo = false,
  });
}
