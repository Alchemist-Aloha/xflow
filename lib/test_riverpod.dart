import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class FeedNotifier extends AsyncNotifier<int> {
  @override
  FutureOr<int> build() async {
    print(ref);
    print(state);
    return 0;
  }
}

final feedProvider = AsyncNotifierProvider.autoDispose<FeedNotifier, int>(FeedNotifier.new);
