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
}
