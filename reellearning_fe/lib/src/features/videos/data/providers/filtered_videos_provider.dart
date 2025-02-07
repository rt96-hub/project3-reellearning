import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../auth/data/providers/auth_provider.dart';

class FilteredVideosNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  static const String _functionUrl = 'https://us-central1-reellearning-prj3.cloudfunctions.net/get_filtered_videos';

  Future<List<Map<String, dynamic>>> _fetchVideos(String sourceType, String sourceId, String videoType) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return [];

    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse(
        '$_functionUrl'
        '?source_type=$sourceType'
        '&source_id=$sourceId'
        '&video_type=$videoType'
      ),
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['videos']);
    }
    throw Exception('Failed to load videos');
  }

  Future<void> loadVideos(String sourceType, String sourceId, String videoType) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchVideos(sourceType, sourceId, videoType));
  }

  @override
  Future<List<Map<String, dynamic>>> build() async {
    return [];
  }
}

final filteredVideosProvider = AsyncNotifierProvider<FilteredVideosNotifier, List<Map<String, dynamic>>>(
  () => FilteredVideosNotifier(),
);
