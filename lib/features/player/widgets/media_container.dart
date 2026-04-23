import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/tweet.dart';
import '../player_pool_provider.dart';

class TiktokMediaContainer extends ConsumerStatefulWidget {
  final Tweet tweet;
  final bool isVisible;

  const TiktokMediaContainer({
    super.key,
    required this.tweet,
    required this.isVisible,
  });

  @override
  ConsumerState<TiktokMediaContainer> createState() => _TiktokMediaContainerState();
}

class _TiktokMediaContainerState extends ConsumerState<TiktokMediaContainer> {
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  @override
  Widget build(BuildContext context) {
    if (widget.tweet.mediaUrls.isEmpty) {
      return const Center(child: Text('No Media'));
    }

    if (!widget.tweet.isVideo) {
      return _buildImageGallery();
    }

    final pool = ref.watch(playerPoolProvider);
    final instance = pool[widget.tweet.id];

    if (instance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.isVisible) {
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

        // Determine orientation based on current player state
        final width = instance.player.state.width;
        final height = instance.player.state.height;
        final isLandscape = (width ?? 0) > (height ?? 0);

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
                child: SizedBox.expand(
                  child: Center(
                    child: Video(
                      key: _videoKey,
                      controller: instance.controller,
                      controls: MaterialVideoControls,
                      onExitFullscreen: () async {
                        await SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
                      },
                    ),
                  ),
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
                  // Manually handle orientation before entering fullscreen if needed,
                  // but MaterialVideoControls usually handles it if configured via theme.
                  // For version 1.3.1, we can also use SystemChrome directly in a wrapper if needed.
                  _videoKey.currentState?.enterFullscreen();
                  if (isLandscape) {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                  } else {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageGallery() {
    if (widget.tweet.mediaUrls.length == 1) {
      return SizedBox.expand(
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.tweet.mediaUrls.first,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.tweet.mediaUrls.length,
      itemBuilder: (context, index) {
        return SizedBox.expand(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.tweet.mediaUrls[index],
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }
}
