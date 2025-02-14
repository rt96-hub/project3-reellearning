import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:reellearning_fe/src/features/onboarding/presentation/screens/interests_screen.dart';

final tagSuggestionsProvider = AsyncNotifierProvider<TagSuggestionsNotifier, List<TagData>>(() {
  return TagSuggestionsNotifier();
});

class TagSuggestionsNotifier extends AsyncNotifier<List<TagData>> {
  // TODO: Move this to a configuration file
  static const String _functionBaseUrl = 'https://us-central1-reellearning-prj3.cloudfunctions.net';

  @override
  List<TagData> build() {
    return [];
  }

  Future<List<TagData>> getSuggestions(String className, [String? description]) async {
    state = const AsyncValue.loading();
    try {
      // Get the current user's ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();

      // Call the Firebase Function
      final url = Uri.parse('$_functionBaseUrl/retrieve_suggested_class_tags');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'className': className,
          'description': description ?? '',
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body)['error'] ?? 'Unknown error occurred';
        throw Exception('Failed to get tag suggestions: $error');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'success' || !data.containsKey('tags')) {
        throw Exception('Invalid response format: missing status or tags');
      }

      final suggestions = data['tags'] as List;
      
      // Convert the suggestions directly to TagData since they match our format
      final tagDocs = suggestions.map((suggestion) {
        return TagData(
          id: suggestion['id'],
          tag: suggestion['tag'],
          relatedTags: List<String>.from(suggestion['relatedTags'] ?? []),
        );
      }).toList();

      state = AsyncValue.data(tagDocs);
      return tagDocs;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
} 