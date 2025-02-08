import 'package:flutter_riverpod/flutter_riverpod.dart';

final tabStateProvider = StateNotifierProvider<TabStateNotifier, int>((ref) {
  return TabStateNotifier();
});

class TabStateNotifier extends StateNotifier<int> {
  TabStateNotifier() : super(0);

  void setTab(int index) {
    if (state != index) {
      state = index;
    }
  }
}
