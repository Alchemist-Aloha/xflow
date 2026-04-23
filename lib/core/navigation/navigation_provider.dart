import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainTab { media, subscriptions }

class NavigationState {
  final MainTab currentTab;
  final String? selectedUser; // If not null, show UserDetails or UserMediaFeed
  final int? userMediaInitialIndex;

  NavigationState({
    this.currentTab = MainTab.media,
    this.selectedUser,
    this.userMediaInitialIndex,
  });

  NavigationState copyWith({
    MainTab? currentTab,
    String? selectedUser,
    int? userMediaInitialIndex,
    bool clearUser = false,
    bool clearMediaIndex = false,
  }) {
    return NavigationState(
      currentTab: currentTab ?? this.currentTab,
      selectedUser: clearUser ? null : (selectedUser ?? this.selectedUser),
      userMediaInitialIndex: (clearUser || clearMediaIndex) ? null : (userMediaInitialIndex ?? this.userMediaInitialIndex),
    );
  }
}

class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => NavigationState();

  void setTab(MainTab tab) {
    state = state.copyWith(currentTab: tab, clearUser: true);
  }

  void selectUser(String screenName) {
    state = state.copyWith(selectedUser: screenName, clearMediaIndex: true);
  }

  void openUserMedia(String screenName, int index) {
    state = state.copyWith(selectedUser: screenName, userMediaInitialIndex: index);
  }

  void back() {
    if (state.userMediaInitialIndex != null) {
      state = state.copyWith(clearMediaIndex: true);
    } else if (state.selectedUser != null) {
      state = state.copyWith(clearUser: true);
    }
  }
}

final navigationProvider = NotifierProvider<NavigationNotifier, NavigationState>(
  NavigationNotifier.new,
);
