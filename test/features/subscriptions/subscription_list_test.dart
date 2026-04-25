import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xflow/features/subscriptions/subscription_list_screen.dart';
import 'package:xflow/core/database/entities.dart';

void main() {
  group('SubscriptionListScreen Widget Tests', () {
    testWidgets('renders empty state when no subscriptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionListProvider
                .overrideWith(() => MockSubscriptionListNotifier([])),
          ],
          child: const MaterialApp(
            home: SubscriptionListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No subscriptions found.'), findsOneWidget);
    });

    testWidgets('renders list of subscriptions', (WidgetTester tester) async {
      final mockSubs = [
        Subscription(
          id: '1',
          screenName: 'user1',
          name: 'User One',
          profileImageUrl: 'https://test.com/u1.jpg',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionListProvider
                .overrideWith(() => MockSubscriptionListNotifier(mockSubs)),
          ],
          child: const MaterialApp(
            home: SubscriptionListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('User One'), findsOneWidget);
      expect(find.text('@user1'), findsOneWidget);
    });
  });
}

class MockSubscriptionListNotifier extends SubscriptionListNotifier {
  final List<Subscription> initialSubs;
  MockSubscriptionListNotifier(this.initialSubs);

  @override
  SubscriptionListState build() {
    return SubscriptionListState(
      allSubscriptions: initialSubs,
      isLoading: false,
    );
  }

  @override
  Future<void> refresh() async {}
}
