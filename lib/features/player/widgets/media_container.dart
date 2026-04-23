import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/tweet.dart';
import '../player_pool_provider.dart';

class TiktokMediaContainer extends ConsumerWidget {
  final Tweet tweet;
  final bool isVisible;

  const TiktokMediaContainer({
    super.key,
    required this.tweet,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!tweet.mediaUrls.isNotEmpty) {
      return const Center(child: Text('No Media'));
    }

    if (!tweet.isVideo) {
      return CachedNetworkImage(
        imageUrl: tweet.mediaUrls.first,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    }

    final pool = ref.watch(playerPoolProvider);
    final instance = pool[tweet.id];

    if (instance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle play/pause logic based on visibility
    // Note: In a real app, we'd use a more robust way to trigger this to avoid re-playing on every build
    if (isVisible) {
      instance.player.play();
    } else {
      instance.player.pause();
    }

    return StreamBuilder(
      stream: instance.player.stream.error,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                const SizedBox(height: 16),
                Text('Video Error: ${snapshot.data}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (instance.player.state.playing) {
                  instance.player.pause();
                } else {
                  instance.player.play();
                }
              },
              child: AbsorbPointer(
                child: Video(
                  controller: instance.controller,
                  controls: NoVideoControls,
                ),
              ),
            ),
            // Custom Full Screen Button
            Positioned(
              right: 8,
              bottom: 100, // Above the text overlay
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 32),
                onPressed: () {
                  enterFullscreen(context);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
