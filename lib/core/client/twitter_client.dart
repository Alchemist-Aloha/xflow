import '../models/tweet.dart';

class TwitterClient {
  Future<List<Tweet>> fetchTrendingMedia() async {
    // In a final implementation, this would use squawker_source/lib/client/client.dart
    // to fetch real data from Twitter/X.
    return [
      Tweet(
        id: '1',
        text: 'Flutter Media Kit on Linux is smooth!',
        userHandle: '@flutter_dev',
        mediaUrls: ['https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4'],
        isVideo: true,
      ),
      Tweet(
        id: '2',
        text: 'Check out this beautiful landscape.',
        userHandle: '@nature_pics',
        mediaUrls: ['https://images.unsplash.com/photo-1506744038136-46273834b3fb?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80'],
        isVideo: false,
      ),
      Tweet(
        id: '3',
        text: 'Big Buck Bunny - classic test video.',
        userHandle: '@blender_foundation',
        mediaUrls: ['https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4'],
        isVideo: true,
      ),
      Tweet(
        id: '4',
        text: 'Space exploration is the future.',
        userHandle: '@nasa',
        mediaUrls: ['https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80'],
        isVideo: false,
      ),
    ];
  }
}
