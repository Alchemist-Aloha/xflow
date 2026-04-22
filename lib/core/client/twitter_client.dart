import '../models/tweet.dart';

class TwitterClient {
  Future<List<Tweet>> fetchTrendingMedia() async {
    // This will be replaced with real Squawker logic in next steps
    return [
      Tweet(
        id: '1',
        text: 'Sample Video',
        userHandle: '@test',
        mediaUrls: ['https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4'],
        isVideo: true,
      ),
    ];
  }
}
