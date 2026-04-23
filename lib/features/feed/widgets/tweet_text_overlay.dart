import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/models/tweet.dart';
import '../../../core/navigation/navigation_provider.dart';

class TweetTextOverlay extends ConsumerStatefulWidget {
  final Tweet tweet;

  const TweetTextOverlay({super.key, required this.tweet});

  @override
  ConsumerState<TweetTextOverlay> createState() => _TweetTextOverlayState();
}

class _TweetTextOverlayState extends ConsumerState<TweetTextOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.9),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 20),
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
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    String dateStr = "";
    if (widget.tweet.createdAt != null) {
      dateStr = " • ${DateFormat('MMM d, HH:mm').format(widget.tweet.createdAt!)}";
    }

    return GestureDetector(
      onTap: () {
        final handle = widget.tweet.userHandle.replaceFirst('@', '');
        ref.read(navigationProvider.notifier).selectUser(handle);
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            backgroundImage: widget.tweet.userAvatarUrl != null
                ? CachedNetworkImageProvider(widget.tweet.userAvatarUrl!)
                : null,
            child: widget.tweet.userAvatarUrl == null
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tweet.userHandle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr.replaceFirst(" • ", ""),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [
                        Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTweetText() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tweet.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
              shadows: [
                Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black),
              ],
            ),
            maxLines: _isExpanded ? null : 3,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
