import 'package:flutter_test/flutter_test.dart';
import 'package:xflow/core/client/transaction_id_service.dart';

void main() {
  test('normalizeJavaScriptResult unwraps quoted values and nulls', () {
    expect(TransactionIdService.normalizeJavaScriptResult(null), isNull);
    expect(TransactionIdService.normalizeJavaScriptResult('null'), isNull);
    expect(
      TransactionIdService.normalizeJavaScriptResult('"txid-123"'),
      'txid-123',
    );
    expect(
      TransactionIdService.normalizeJavaScriptResult('txid-456'),
      'txid-456',
    );
  });

  test('embedded generator keeps critical remote additional2.js markers', () {
    final script = TransactionIdService.embeddedGeneratorScript;

    expect(script, contains("document.querySelectorAll('[name^=tw]')[0]"));
    expect(script, contains("new RTCPeerConnection()"));
    expect(script, contains("r.createOffer()"));
    expect(script, contains('u.currentTime = Math.round(r / 10) * 10;'));
    expect(script, contains("new Uint32Array([o]).buffer"));
    expect(script, contains('obfiowerehiring'));
    expect(
        script,
        contains(
            "new Uint8Array(await wc([t, n, o].join('!') + 'obfiowerehiring' + i))"));
  });
}
