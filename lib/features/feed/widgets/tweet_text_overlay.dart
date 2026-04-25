import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/models/tweet.dart';
import '../../../core/navigation/navigation_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/database/entities.dart';
import '../../subscriptions/subscription_list_screen.dart';
import '../feed_provider.dart';
import '../tweet_detail_screen.dart';

class TweetTextOverlay extends ConsumerStatefulWidget {
  final Tweet tweet;
  final VoidCallback? onFullscreen;

  const TweetTextOverlay({super.key, required this.tweet, this.onFullscreen});

  @override
  ConsumerState<TweetTextOverlay> createState() => _TweetTextOverlayState();
}

class _TweetTextOverlayState extends ConsumerState<TweetTextOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Action Buttons (Right Side)
        Positioned(
          right: 12,
          bottom: 110,
          child: _buildActionButtons(),
        ),
        // Text Overlay (Bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 100, 80, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUserHeader(context),
                const SizedBox(height: 12),
                _buildTweetText(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: widget.tweet.isLiked ? Icons.favorite : Icons.favorite_border,
          color: widget.tweet.isLiked ? Colors.red : Colors.white,
          label: _formatCount(widget.tweet.favoriteCount),
          onTap: () {
            ref.read(feedNotifierProvider.notifier).toggleLike(widget.tweet.id);
          },
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(widget.tweet.replyCount),
          onTap: () {
            TweetRepliesSheet.show(context, widget.tweet);
          },
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.share_outlined,
          label: "Share",
          onTap: () {
            // TODO: Implement share
          },
        ),
        if (widget.onFullscreen != null && widget.tweet.isVideo) ...[
          const SizedBox(height: 16),
          _ActionButton(
            icon: Icons.fullscreen,
            label: "Full",
            onTap: widget.onFullscreen!,
          ),
        ],
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildUserHeader(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionListProvider);
    final isSubscribed = subscriptionState.isSubscribed(widget.tweet.userHandle);

    String dateStr = "";
    if (widget.tweet.createdAt != null) {
      try {
        final date = widget.tweet.createdAt!.toLocal();
        dateStr = " • ${DateFormat.yMMMd().add_Hm().format(date)}";
      } catch (e) {
        AppLogger.log('XFLOW: Error formatting date: $e');
        dateStr = " • ERR";
      }
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            final handle = widget.tweet.userHandle.replaceFirst('@', '');
            ref.read(navigationProvider.notifier).selectUser(handle);
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            backgroundImage: widget.tweet.userAvatarUrlHighRes != null
                ? CachedNetworkImageProvider(widget.tweet.userAvatarUrlHighRes!)
                : null,
            child: widget.tweet.userAvatarUrlHighRes == null
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  final handle = widget.tweet.userHandle.replaceFirst('@', '');
                  ref.read(navigationProvider.notifier).selectUser(handle);
                },
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.tweet.userHandle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black54),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSubscribed) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle,
                          color: Colors.blueAccent, size: 16),
                    ],
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr.replaceFirst(" • ", ""),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    shadows: [
                      Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black54),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!isSubscribed)
          TextButton(
            onPressed: () {
              ref.read(subscriptionListProvider.notifier).toggleSubscription(
                    Subscription(
                      id: widget.tweet.userHandle,
                      screenName: widget.tweet.userHandle.replaceFirst('@', ''),
                      name: widget.tweet.userHandle,
                      profileImageUrl: widget.tweet.userAvatarUrl,
                    ),
                  );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 30),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Subscribe', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildTweetText() {
    final text = widget.tweet.text;
    final List<InlineSpan> spans = [];

    // Simple hashtag and mention parsing
    final words = text.split(RegExp(r'(\s+)'));
    for (final word in words) {
      if (word.startsWith('#') && word.length > 1) {
        spans.add(
          WidgetSpan(
            child: GestureDetector(
              onTap: () {
                ref.read(navigationProvider.notifier).selectHashtag(word);
              },
              child: Text(
                word,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      } else if (word.startsWith('@') && word.length > 1) {
        spans.add(
          WidgetSpan(
            child: GestureDetector(
              onTap: () {
                final handle = word.replaceFirst('@', '');
                ref.read(navigationProvider.notifier).selectUser(handle);
              },
              child: Text(
                word,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: word));
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: spans,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
                shadows: [
                  Shadow(
                      offset: Offset(0, 1), blurRadius: 2, color: Colors.black),
                ],
              ),
            ),
            maxLines: _isExpanded ? null : 3,
            overflow:
                _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (!_isExpanded && widget.tweet.text.length > 100)
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text(
                "Read more",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color = Colors.white,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.1),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
                shadows: const [
                  Shadow(
                      offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black54),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
