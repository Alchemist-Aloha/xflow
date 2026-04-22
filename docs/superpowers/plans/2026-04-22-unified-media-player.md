# XFlow Unified Media Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a unified media player widget that handles both images and videos using `media_kit`, with a built-in prefetching mechanism for smooth transitions.

**Architecture:** We'll use a `TiktokMediaContainer` that wraps either a `Video` widget (from `media_kit_video`) or a `CachedNetworkImage`. A `PlayerPoolProvider` will manage the lifecycle of `media_kit` instances based on a sliding window.

**Tech Stack:** Flutter, Riverpod, media_kit, cached_network_image

---

### Task 1: Initialize MediaKit in Main

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add initialization logic to `main()`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart'; // Add this

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // Add this
  runApp(const ProviderScope(child: XFlowApp()));
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize media_kit"
```

---

### Task 2: Implement Player Pool & Prefetch Logic

**Files:**
- Create: `lib/features/player/player_pool_provider.dart`

- [ ] **Step 1: Create the `PlayerPoolProvider`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerInstance {
  final Player player;
  final VideoController controller;

  PlayerInstance(this.player, this.controller);

  void dispose() {
    player.dispose();
  }
}

class PlayerPoolNotifier extends Notifier<Map<String, PlayerInstance>> {
  @override
  Map<String, PlayerInstance> build() {
    ref.onDispose(() {
      for (final instance in state.values) {
        instance.dispose();
      }
    });
    return {};
  }

  void warmup(String id, String url) {
    if (state.containsKey(id)) return;

    final player = Player();
    final controller = VideoController(player);
    player.open(Media(url), play: false); // Pre-load but don't play
    
    state = {...state, id: PlayerInstance(player, controller)};
  }

  void cleanupExcept(Set<String> activeIds) {
    final newState = <String, PlayerInstance>{};
    for (final entry in state.entries) {
      if (activeIds.contains(entry.key)) {
        newState[entry.key] = entry.value;
      } else {
        entry.value.dispose();
      }
    }
    state = newState;
  }
}

final playerPoolProvider = NotifierProvider<PlayerPoolNotifier, Map<String, PlayerInstance>>(
  PlayerPoolNotifier.new,
);
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/player/player_pool_provider.dart
git commit -m "feat: add player pool and prefetch logic"
```

---

### Task 3: Create Unified Media Container Widget

**Files:**
- Create: `lib/features/player/widgets/media_container.dart`

- [ ] **Step 1: Implement `TiktokMediaContainer`**

```dart
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

    if (isVisible) {
      instance.player.play();
    } else {
      instance.player.pause();
    }

    return Video(controller: instance.controller);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/player/widgets/media_container.dart
git commit -m "feat: add unified media container widget"
```
