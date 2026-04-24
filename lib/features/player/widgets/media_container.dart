import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/tweet.dart';
import '../../../core/utils/media_cache_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../feed/widgets/text_tweet_card.dart';
import '../player_pool_provider.dart';
import '../../settings/settings_provider.dart';

class TiktokMediaContainer extends ConsumerStatefulWidget {
  final Tweet tweet;
  final bool isVisible;
  final Widget? overlay;
  final VoidCallback? onPlaybackError;

  const TiktokMediaContainer({
    super.key,
    required this.tweet,
    required this.isVisible,
    this.overlay,
    this.onPlaybackError,
  });

  @override
  ConsumerState<TiktokMediaContainer> createState() => _TiktokMediaContainerState();
}

class _TiktokMediaContainerState extends ConsumerState<TiktokMediaContainer> {
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  int _imageIndex = 0;
  int _retryCount = 0;
  StreamSubscription? _errorSubscription;

  @override
  void dispose() {
    _errorSubscription?.cancel();
    super.dispose();
  }

  void _handleError(dynamic error) {
    final settings = ref.read(settingsProvider);
    if (_retryCount < settings.playbackRetryLimit) {
      _retryCount++;
      AppLogger.log('XFLOW: Video playback error. Retrying ($_retryCount/${settings.playbackRetryLimit})... Error: $error');
      
      final pool = ref.read(playerPoolProvider);
      final instance = pool[widget.tweet.id];
      if (instance != null) {
        // Re-open media to retry
        instance.player.open(Media(widget.tweet.mediaUrls.first), play: widget.isVisible);
      }
    } else {
      AppLogger.log('XFLOW: Video playback failed after retry. Skipping item.');
      widget.onPlaybackError?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tweet.mediaUrls.isEmpty) {
      return Stack(
        children: [
          TextTweetCard(text: widget.tweet.text),
          if (widget.overlay != null) widget.overlay!,
        ],
      );
    }

    if (!widget.tweet.isVideo) {
      return Stack(
        children: [
          _buildImageGallery(),
          if (widget.tweet.mediaUrls.length > 1)
            Positioned(
              bottom: 120, // Above the text overlay
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.tweet.mediaUrls.length, (index) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _imageIndex == index 
                        ? Colors.white 
                        : Colors.white.withValues(alpha: 0.4),
                    ),
                  );
                }),
              ),
            ),
          if (widget.overlay != null) widget.overlay!,
        ],
      );
    }

    final pool = ref.watch(playerPoolProvider);
    final instance = pool[widget.tweet.id];

    if (instance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Subscribe to errors if not already doing so
    _errorSubscription ??= instance.player.stream.error.listen(_handleError);

    if (widget.isVisible) {
      instance.player.play();
    } else {
      instance.player.pause();
    }

    final settings = ref.watch(settingsProvider);
    return StreamBuilder(
      stream: instance.player.stream.error,
      builder: (context, snapshot) {
        if (snapshot.hasData && _retryCount >= settings.playbackRetryLimit) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                const SizedBox(height: 16),
                const Text('Playback failed. Moving to next...', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Error: ${snapshot.data}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
                    child: RepaintBoundary(
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
            ),
            if (widget.overlay != null) widget.overlay!,
            // Custom Full Screen Button
            Positioned(
              right: 16,
              bottom: 120, // Above the text overlay
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 36),
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
            // Progress Bar at the very bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildProgressBar(instance),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(PlayerInstance instance) {
    return StreamBuilder<Duration>(
      stream: instance.player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = instance.player.state.duration;
        
        if (duration == Duration.zero) return const SizedBox.shrink();
        
        final progress = position.inMilliseconds / duration.inMilliseconds;
        
        return Container(
          height: 2,
          width: double.infinity,
          color: Colors.white12,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildImageGallery() {
    if (widget.tweet.mediaUrls.length == 1) {
      return SizedBox.expand(
        child: Center(
          child: CachedNetworkImage(
            cacheManager: CustomMediaCacheManager.getInstance(),
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
      onPageChanged: (index) {
        setState(() {
          _imageIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return SizedBox.expand(
          child: Center(
            child: CachedNetworkImage(
              cacheManager: CustomMediaCacheManager.getInstance(),
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
