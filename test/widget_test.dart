import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xflow/main.dart';
import 'package:xflow/core/client/background_sync.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  BackgroundSync.enabled = false;

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: XFlowApp()));

    // Verify that the app renders something
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
