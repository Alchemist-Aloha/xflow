import 'package:flutter_riverpod/flutter_riverpod.dart';
class TestNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() {
    state = 1;
  }
}
