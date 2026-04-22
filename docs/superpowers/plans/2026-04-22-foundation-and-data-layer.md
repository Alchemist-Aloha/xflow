# XFlow Foundation & Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize the project structure and adapt the Squawker Twitter client for fetching media-heavy feeds.

**Architecture:** We will setup a clean Material 3 project and extract the essential networking and modeling code from `squawker_source`. We'll use Riverpod for state management.

**Tech Stack:** Flutter, Riverpod, http, flutter_lints

---

### Task 1: Project Scaffolding & Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/main.dart`

- [ ] **Step 1: Update `pubspec.yaml` with essential dependencies**

```yaml
name: xflow
description: TikTok-style player for Twitter/X media.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4
  http: ^1.2.1
  json_annotation: ^4.9.0
  cached_network_image: ^3.3.1
  flutter_cache_manager: ^3.3.1
  path_provider: ^2.1.3
  shared_preferences: ^2.2.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.9
  json_serializable: ^6.8.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Run `flutter pub get`**

Run: `flutter pub get`
Expected: Success

- [ ] **Step 3: Create a minimal `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: XFlowApp()));
}

class XFlowApp extends StatelessWidget {
  const XFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XFlow',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const Scaffold(
        body: Center(child: Text('XFlow Initialized')),
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml lib/main.dart
git commit -m "chore: initial project scaffolding"
```

---

### Task 2: Porting the Twitter Client (Core)

**Files:**
- Create: `lib/core/client/twitter_client.dart`
- Create: `lib/core/models/tweet.dart`

- [ ] **Step 1: Create a simplified `Tweet` model**

```dart
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
```

- [ ] **Step 2: Port a basic fetcher from `squawker_source/lib/client/client.dart`**
(Note: We'll start with a mockable interface to ensure the UI can be built while refining the Squawker logic)

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/
git commit -m "feat: add basic twitter client and tweet model"
```
