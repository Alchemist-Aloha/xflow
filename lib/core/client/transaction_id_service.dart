import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../utils/app_logger.dart';
import 'account_provider.dart';
import 'x_api_constants.dart';

class TransactionIdService {
  TransactionIdService._();

  static final TransactionIdService instance = TransactionIdService._();

  WebViewController? _controller;
  bool _isReady = false;
  bool _scriptInstalled = false;

  void attachController(WebViewController controller) {
    _controller = controller;
    _scriptInstalled = false;
  }

  void markReady(bool ready) {
    _isReady = ready;
    if (!ready) {
      _scriptInstalled = false;
    }
  }

  Future<String?> generateForRequest(String path,
      {String method = 'GET'}) async {
    final controller = _controller;
    if (controller == null || !_isReady) {
      return null;
    }

    try {
      await _ensureScriptInstalled(controller);
      final rawResult = await controller.runJavaScriptReturningResult('''
        (async function() {
          return await window.__xflowGenerateTransactionId(
            ${jsonEncode(path)},
            ${jsonEncode(method)}
          );
        })();
      ''');
      return normalizeJavaScriptResult(rawResult);
    } catch (e) {
      AppLogger.log('TXID local generation failed: ${e.runtimeType}: $e');
      return null;
    }
  }

  Future<void> _ensureScriptInstalled(WebViewController controller) async {
    if (_scriptInstalled) return;
    await controller.runJavaScript(_transactionIdGeneratorScript);
    _scriptInstalled = true;
  }

  static String? normalizeJavaScriptResult(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    if (text == 'null' || text.isEmpty) return null;
    if (text.startsWith('"') && text.endsWith('"') && text.length >= 2) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  @visibleForTesting
  static String get embeddedGeneratorScript => _transactionIdGeneratorScript;
}

class TransactionIdWebViewHost extends ConsumerStatefulWidget {
  const TransactionIdWebViewHost({super.key});

  @override
  ConsumerState<TransactionIdWebViewHost> createState() =>
      _TransactionIdWebViewHostState();
}

class _TransactionIdWebViewHostState
    extends ConsumerState<TransactionIdWebViewHost> {
  late final WebViewController _controller;
  String? _loadedAccountId;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(xMobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            final ready = url.startsWith('https://x.com/');
            TransactionIdService.instance.markReady(ready);
            if (ready) {
              AppLogger.log('TXID WebView ready at $url');
            }
          },
        ),
      );
    TransactionIdService.instance.attachController(_controller);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    if (account == null) {
      TransactionIdService.instance.markReady(false);
      _loadedAccountId = null;
      return const SizedBox.shrink();
    }

    if (_loadedAccountId != account.id) {
      _loadedAccountId = account.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.loadRequest(Uri.parse(LoginScreen.homeUrl));
      });
    }

    return IgnorePointer(
      child: Opacity(
        opacity: 0.01,
        child: SizedBox(
          width: 1,
          height: 1,
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

const String _transactionIdGeneratorScript = r'''
(() => {
  if (window.__xflowGenerateTransactionId) return;

  // Source-aligned port of fa0311/twitter-tid-deobf-fork output/additional2.js.
  const W = () => {
    let Sc;
    let zc;
    let Yc = [];

    const lc = (n) =>
      btoa(Array.from(n).map((n) => String.fromCharCode(n)).join('')).replace(
        /=/g,
        ''
      );

    const Jc = (n, t) => (n && n.getAttribute(t)) || '';

    const hc = (n) => (typeof n === 'string' ? new TextEncoder().encode(n) : n);

    const wc = (n) => crypto.subtle.digest('sha-256', hc(n));

    const pc = (n) => (n < 16 ? '0' : '') + n.toString(16);

    const Fc = (n) =>
      Array.from(n).map((n) => (n.parentElement?.removeChild(n), n));

    const Ac = (n, t, r) => (t ? n ^ r[0] : n);

    const Pc = () => {
      const n = Jc(document.querySelectorAll('[name^=tw]')[0], 'content');
      if (!n) return null;
      return new Uint8Array(atob(n).split('').map((n) => n.charCodeAt(0)));
    };

    const Uc = (n, t) =>
      (Sc =
        Sc ||
        Jc(Fc(document.querySelectorAll(n))[t[5] % 4]?.childNodes?.[0]?.childNodes?.[1], 'd')
          .substring(9)
          .split('C')
          .map((n) =>
            n
              .replace(/[^\d]+/g, ' ')
              .trim()
              .split(' ')
              .map(Number)
          ));

    const Mc = (n, t, r, u) => {
      const c = (n * (r - t)) / 255 + t;
      return u ? Math.floor(c) : c.toFixed(2);
    };

    const yc = (n) => ({
      color: [
        '#' + pc(n[0]) + pc(n[1]) + pc(n[2]),
        '#' + pc(n[3]) + pc(n[4]) + pc(n[5]),
      ],
      transform: ['rotate(0deg)', 'rotate(' + Mc(n[6], 60, 360, true) + 'deg)'],
      easing:
        'cubic-bezier(' +
        Array.from(n.slice(7))
          .map((n, t) => Mc(n, t % 2 ? -1 : 0, 1, false))
          .join() +
        ')',
    });

    const ensureProbe = () => {
      let probe = document.getElementById('__xflow_txid_probe');
      if (!probe) {
        probe = document.createElement('div');
        probe.id = '__xflow_txid_probe';
        probe.style.position = 'absolute';
        probe.style.left = '-9999px';
        probe.style.top = '-9999px';
        probe.style.width = '1px';
        probe.style.height = '1px';
        probe.style.pointerEvents = 'none';
        document.body.appendChild(probe);
      }
      return probe;
    };

    const kn = ensureProbe();
    const On = () => kn.remove();

    const Ic = (n, t, r) => {
      if (!n.animate) return;
      const u = n.animate(yc(t), 4096);
      u.pause();
      u.currentTime = Math.round(r / 10) * 10;
    };

    const Ec = (n) => {
      if (!zc) {
        const an = Uc('.r-0', n);
        if (!an || !an[n[33] % 16]) return null;

        new Promise(() => {
          try {
            const r = new RTCPeerConnection();
            const c = Math.random().toString(36);
            r.createDataChannel(c);
            r.createOffer()
              .then((W) => {
                try {
                  const t = W.sdp || c;
                  Yc = Array.from(hc([t[n[5] % 8] || '4', t[n[8] % 8] || '0']));
                  r.close();
                } catch (_) {}
              })
              .catch(() => 0);
          } catch (_) {}
        }).catch(() => 0);

        Ic(
          kn,
          an[n[33] % 16],
          (n[28] % 16) * (n[28] % 16) * (n[37] % 16)
        );
        const Gn = getComputedStyle(kn);
        zc = Array.from(
          ('' + Gn.color + Gn.transform).matchAll(/([\d.-]+)/g)
        )
          .map((n) => Number(Number(n[0]).toFixed(2)).toString(16))
          .join('')
          .replace(/[.-]/g, '');
        On();
      }
      return zc;
    };

    return async (n, t) => {
      const o = Math.floor((Date.now() - 1682924400000) / 1e3);
      const e = new Uint8Array(new Uint32Array([o]).buffer);
      const f = Pc();
      if (!f) return null;
      const i = Ec(f);
      if (!i) return null;

      return lc(
        new Uint8Array(
          [Math.random() * 256]
            .concat(
              Array.from(f),
              Array.from(e),
              Array.from(
                new Uint8Array(await wc([t, n, o].join('!') + 'obfiowerehiring' + i))
              )
                .slice(0, 16)
                .concat(Yc),
              [3]
            )
            .map(Ac)
        )
      );
    };
  };

  window.__xflowGenerateTransactionId = W();
})();
''';
