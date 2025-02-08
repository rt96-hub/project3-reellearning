import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class VideoControllerState {
  final VideoPlayerController? controller;
  final bool wasPlaying;
  final String? error;

  const VideoControllerState({
    this.controller,
    this.wasPlaying = false,
    this.error,
  });

  VideoControllerState copyWith({
    VideoPlayerController? controller,
    bool? wasPlaying,
    String? error,
  }) {
    return VideoControllerState(
      controller: controller ?? this.controller,
      wasPlaying: wasPlaying ?? this.wasPlaying,
      error: error ?? this.error,
    );
  }
}

class VideoControllerNotifier extends StateNotifier<VideoControllerState> {
  VideoControllerNotifier() : super(const VideoControllerState());

  void setController(VideoPlayerController controller) {
    state = state.copyWith(controller: controller);
    debugPrint('Video controller set');
  }

  Future<void> pauseAndRemember() async {
    final controller = state.controller;
    if (controller == null) return;

    final wasPlaying = controller.value.isPlaying;
    if (wasPlaying) {
      await controller.pause();
      state = state.copyWith(wasPlaying: true);
      debugPrint('Video paused, was playing: $wasPlaying');
    }
  }

  Future<void> resumeIfNeeded() async {
    final controller = state.controller;
    if (controller == null) return;

    if (state.wasPlaying) {
      await controller.play();
      state = state.copyWith(wasPlaying: false);
      debugPrint('Video resumed from previous state');
    }
  }

  void dispose() {
    state.controller?.dispose();
    state = const VideoControllerState();
    debugPrint('Video controller disposed');
  }
}

final videoControllerProvider =
    StateNotifierProvider<VideoControllerNotifier, VideoControllerState>((ref) {
  return VideoControllerNotifier();
});
