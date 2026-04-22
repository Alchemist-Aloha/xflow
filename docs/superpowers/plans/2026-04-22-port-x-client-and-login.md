# Port X Client Login & Data Query Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Twitter/X authentication (login via WebView) and data querying (GraphQL SearchTimeline) logic from Squawker to XFlow.

**Architecture:** 
1. **Auth Layer:** Use `webview_flutter` to capture cookies/tokens and store them in `sqflite`.
2. **Client Layer:** Adapt `TwitterAccount` and `Twitter` (from Squawker's `client.dart`) to provide authenticated requests using `dart_twitter_api`.
3. **Data Layer:** Implement the specific GraphQL queries needed for a media-rich TikTok feed.

**Tech Stack:** Flutter, sqflite, webview_flutter, dart_twitter_api, synchronized

---

### Task 1: Update Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add authentication and data dependencies from Squawker**

```yaml
dependencies:
  # ... existing
  dart_twitter_api: ^0.6.0
  webview_flutter: ^4.13.0
  webview_cookie_manager_plus: ^2.0.17
  sqflite: ^2.3.2
  synchronized: ^3.1.0+1
  logging: ^1.2.0
  ffcache: ^1.1.0
  quiver: ^3.1.0
  crypto: ^3.0.3
```

- [ ] **Step 2: Run `flutter pub get`**

---

### Task 2: Setup Database for Accounts

**Files:**
- Create: `lib/core/database/repository.dart`
- Create: `lib/core/database/entities.dart`

- [ ] **Step 1: Port basic repository and account entities from Squawker**

```dart
// lib/core/database/entities.dart
class Account {
  final String id;
  final String screenName;
  final String authHeader;

  Account({required this.id, required this.screenName, required this.authHeader});

  Map<String, dynamic> toMap() => {'id': id, 'screen_name': screenName, 'auth_header': authHeader};
}
```

---

### Task 3: Port TwitterAccount (Auth Manager)

**Files:**
- Create: `lib/core/client/twitter_account.dart`

- [ ] **Step 1: Implement account storage and retrieval logic**
- [ ] **Step 2: Implement the `fetch` method that injects auth headers**

---

### Task 4: Port Login WebView

**Files:**
- Create: `lib/features/auth/login_screen.dart`

- [ ] **Step 1: Implement the WebView-based login that captures CSRF tokens and cookies**
- [ ] **Step 2: Save the captured account to the repository**

---

### Task 5: Implement Real Data Query in TwitterClient

**Files:**
- Modify: `lib/core/client/twitter_client.dart`

- [ ] **Step 1: Implement `fetchTrendingMedia` using the `SearchTimeline` GraphQL endpoint**
- [ ] **Step 2: Parse the complex GraphQL response into our `Tweet` model**
