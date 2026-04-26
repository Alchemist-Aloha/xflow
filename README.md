# <img src="assets/app_icon.png" alt="App Icon" width="40"/> XFlow

XFlow is a Flutter-based application that reimagines how you consume media from Twitter/X. It provides a seamless, TikTok-style infinite scrolling experience specifically tailored for browsing videos and images from the platform.

By leveraging the robust authentication and data layers originally built for the [Squawker](https://github.com/j-fb/squawker) project, XFlow allows you to securely log in, view media from your subscriptions, and explore trending content in a highly optimized, full-screen player environment.

## ✨ Features

* **TikTok-Style Media Feed:** Infinite vertical scrolling through full-screen media content.
* **Smart Pre-caching:** Automatically warms up the next few videos in your feed so playback starts instantly without buffering.
* **Subscription Management:** Easily manage your X/Twitter subscriptions and view a dedicated feed of their media.
* **Profile & Media Grid:** View user profiles and lazily-loaded grids of their media uploads.
* **Optimized Caching:** Implements `ffcache` and `cached_network_image` to aggressively cache API responses and media assets, dramatically reducing network requests and improving load times.
* **State Preservation:** Keeps your place in the infinite scroll feed even when navigating deep into user profiles or switching tabs.

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (>=3.0.0 <4.0.0)
* Dart SDK
* Android Studio / Xcode (for emulation/deployment)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/xflow.git
   cd xflow
   ```

2. Get the Flutter dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:

   ```bash
   flutter run
   ```

## 📁 Project Structure

* `lib/core/` - Core infrastructure including the database, navigation, and the modified Twitter/X client.
* `lib/features/auth/` - Webview-based login implementation.
* `lib/features/feed/` - The core TikTok-style infinite scrolling feed and associated providers.
* `lib/features/player/` - Video player pool management and rendering.
* `lib/features/profile/` - User profile details and media grid views.
* `lib/features/subscriptions/` - Subscription list management.
* `lib/features/settings/` - App settings and preferences.


## 🛠 Alternative Feed Fetching

XFlow also supports fetching feeds using the [Twitter Internal API Document](https://github.com/fa0311/TwitterInternalAPIDocument). This repository provides detailed insights and tools for interacting with Twitter's internal APIs, offering an alternative method for retrieving media feeds. This can be particularly useful for advanced use cases or when exploring additional data endpoints.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/your-username/xflow/issues).

## 📝 License

MIT
