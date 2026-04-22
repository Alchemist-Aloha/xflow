# Design Spec: TikTok-style Media Player (XFlow)

**Date:** 2026-04-22  
**Status:** Approved  
**Tech Stack:** Flutter, Material 3, Riverpod, media_kit

## 1. Overview
Build a modern, TikTok-style vertical feed for Twitter/X media (videos and images) based on the Squawker client. The focus is on high performance (instant playback), Material 3 aesthetics, and a robust prefetching algorithm.

## 2. Architecture
### Core Layers
- **Data Layer:** Refactor Squawker's `TwitterClient` into a reusable core.
- **State Layer (Riverpod):**
    - `FeedProvider`: Manages the paginated list of `FeedItem` objects.
    - `PrefetchProvider`: Orchestrates the windowing and pre-buffering logic.
    - `PlayerProvider`: Manages a pool of `media_kit` `Player` instances.
- **UI Layer:**
    - `TiktokFeedScreen`: Vertical `PageView`.
    - `TiktokPlayerItem`: Unified widget for video/image playback with overlay controls.
    - `SettingsPage`: Categorized M3 settings.

## 3. Prefetch & Windowing Algorithm
### The "Sliding Window" Strategy
To ensure smooth swiping and low latency:
- **Active (n):** Player is active, audio is enabled, playing.
- **Buffered (n+1):** Player is initialized, media is loaded, paused at frame 0.
- **Warm-up (n+2):** Network request started (range request) to fill cache.
- **Cleanup (n-2, n+3):** Player instances disposed, network requests cancelled if possible.

### Media Cache
- Use `media_kit`'s internal caching or a custom HTTP client for range-request caching of video chunks.
- Images use `cached_network_image` with high-priority pre-decoding for the next 5 items.

## 4. Features
### Sorting & Filtering
- **Sort:** Latest, Popular (Likes/Retweets), Oldest.
- **Filter:** Media Type (Video Only, Image Only, Both), Keywords, User-based.
- Applied at the provider level; changes refresh the prefetch queue.

### Settings Management
- Playback (Autoplay, Loop, Audio default).
- Network (Prefetch depth, Data saver mode).
- Appearance (Material You, Accent colors).

## 5. UI Design (Material 3)
- Full-screen immersive view.
- Overlays: Bottom-left info (username, tweet text), Right-side vertical action bar.
- Thin bottom progress indicator for videos.
