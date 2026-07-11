import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/client/twitter_client.dart';

void main() {
  group('TwitterClient API document parity', () {
    test('uses newer SearchTimeline operation id', () {
      expect(
        TwitterClient.graphqlSearchTimelineUriPath,
        '/graphql/R0u1RWRf748KzyGBXvOYRA/SearchTimeline',
      );
    });
  });
}
