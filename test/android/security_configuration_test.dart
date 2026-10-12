import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const mainPath = 'android/app/src/main';

  test('Android wires backup exclusions and scoped cleartext policy', () {
    final manifest = File('$mainPath/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
  });

  test('Only the existing transaction-ID fallback permits cleartext', () {
    final policy = File(
      '$mainPath/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(policy, contains('<base-config cleartextTrafficPermitted="false"'));
    expect(policy.split('<domain-config'), hasLength(2));
    expect(policy, contains('<domain-config cleartextTrafficPermitted="true"'));
    expect(policy.split('<domain '), hasLength(2));
    expect(
      policy,
      contains(
        '<domain includeSubdomains="false">'
        'x-client-transaction-id-generator.xyz</domain>',
      ),
    );
  });

  test('Cloud backup and device transfer exclude app credential storage', () {
    final rules = File(
      '$mainPath/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    for (final mode in ['cloud-backup', 'device-transfer']) {
      final section = rules.split('<$mode>').last.split('</$mode>').first;
      expect(rules, contains('<$mode>'));
      for (final domain in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(section, contains('<exclude domain="$domain" path="." />'));
      }
    }
  });
}
