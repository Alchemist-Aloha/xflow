import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xflow/core/navigation/navigation_provider.dart';

void main() {
  group('NavigationState', () {
    test('initial state has default values', () {
      final state = NavigationState();
      expect(state.currentTab, MainTab.media);
      expect(state.selectedUser, isNull);
      expect(state.userMediaInitialIndex, isNull);
    });

    test('copyWith updates fields correctly', () {
      final state = NavigationState();
      final updated = state.copyWith(
        currentTab: MainTab.subscriptions,
        selectedUser: 'user1',
        userMediaInitialIndex: 5,
      );
      expect(updated.currentTab, MainTab.subscriptions);
      expect(updated.selectedUser, 'user1');
      expect(updated.userMediaInitialIndex, 5);
    });

    test('copyWith handles clearUser and clearMediaIndex', () {
      final state = NavigationState(
        currentTab: MainTab.media,
        selectedUser: 'user1',
        userMediaInitialIndex: 5,
      );

      final clearedMedia = state.copyWith(clearMediaIndex: true);
      expect(clearedMedia.selectedUser, 'user1');
      expect(clearedMedia.userMediaInitialIndex, isNull);

      final clearedUser = state.copyWith(clearUser: true);
      expect(clearedUser.selectedUser, isNull);
      expect(clearedUser.userMediaInitialIndex, isNull);
    });
  });

  group('NavigationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is default NavigationState', () {
      final state = container.read(navigationProvider);
      expect(state.currentTab, MainTab.media);
      expect(state.selectedUser, isNull);
      expect(state.userMediaInitialIndex, isNull);
    });

    test('setTab updates tab and clears user', () {
      // Set some initial state first
      container.read(navigationProvider.notifier).selectUser('user1');

      container.read(navigationProvider.notifier).setTab(MainTab.subscriptions);

      final state = container.read(navigationProvider);
      expect(state.currentTab, MainTab.subscriptions);
      expect(state.selectedUser, isNull);
    });

    test('selectUser sets user and clears media index', () {
      container.read(navigationProvider.notifier).openUserMedia('user1', 10);

      container.read(navigationProvider.notifier).selectUser('user2');

      final state = container.read(navigationProvider);
      expect(state.selectedUser, 'user2');
      expect(state.userMediaInitialIndex, isNull);
    });

    test('openUserMedia sets user and media index', () {
      container.read(navigationProvider.notifier).openUserMedia('user1', 5);

      final state = container.read(navigationProvider);
      expect(state.selectedUser, 'user1');
      expect(state.userMediaInitialIndex, 5);
    });

    group('back', () {
      test('clears media index when it is not null', () {
        container.read(navigationProvider.notifier).openUserMedia('user1', 5);

        container.read(navigationProvider.notifier).back();

        final state = container.read(navigationProvider);
        expect(state.selectedUser, 'user1');
        expect(state.userMediaInitialIndex, isNull);
      });

      test('clears user when media index is null but user is not null', () {
        container.read(navigationProvider.notifier).selectUser('user1');

        container.read(navigationProvider.notifier).back();

        final state = container.read(navigationProvider);
        expect(state.selectedUser, isNull);
      });

      test('does nothing when both are null', () {
        final initialState = container.read(navigationProvider);

        container.read(navigationProvider.notifier).back();

        final state = container.read(navigationProvider);
        expect(state, initialState);
      });
    });
  });
}
