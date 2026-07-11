import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/client/twitter_account.dart';

void main() {
  test('compactForLog flattens whitespace and truncates long values', () {
    final compact = TwitterAccount.compactForLog(
      '  line one\n   line two\tline three  ',
      maxLength: 18,
    );

    expect(compact, 'line one line two...');
  });

  test('compactForLog keeps full value when maxLength is omitted', () {
    final compact = TwitterAccount.compactForLog(
      '  line one\n   line two\tline three  ',
    );

    expect(compact, 'line one line two line three');
  });

  test('formatUriForLog decodes graphql query params', () {
    final uri = Uri.https('x.com', '/i/api/graphql/test/SearchTimeline', {
      'variables': '%7B%22rawQuery%22%3A%22%23latex+-filter%3Areplies%22%7D',
      'features': '%7B%22rweb_video_screen_enabled%22%3Afalse%7D',
    });

    final formatted = TwitterAccount.formatUriForLog(uri);

    expect(formatted, contains('/i/api/graphql/test/SearchTimeline'));
    expect(formatted, contains('rawQuery: #latex -filter:replies'));
    expect(formatted, contains('rweb_video_screen_enabled: false'));
    expect(formatted, isNot(contains('%7B')));
  });

  test('formatTransactionIdForLog returns missing for null and keeps value',
      () {
    expect(TwitterAccount.formatTransactionIdForLog(null), 'missing');
    expect(
      TwitterAccount.formatTransactionIdForLog('txid-123456'),
      'txid-123456',
    );
  });
}
