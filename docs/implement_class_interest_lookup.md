# Implementing Class Interest Tag Suggestions

## Overview
This document outlines the implementation steps for enhancing the class creation flow by suggesting relevant tags based on the class name and description. The system will use OpenAI embeddings and Pinecone vector search to find the most relevant tags from our existing tag database.

## Implementation Steps

### 1. Backend Implementation (Firebase Functions)

#### Create a New Endpoint
Create a new Firebase Function endpoint that will:
1. Accept class name and description
2. Generate embeddings using OpenAI's text-embedding-3-small model
3. Query Pinecone for similar tags
4. Return the results to the frontend

```python
# Example implementation in main.py
@functions_framework.http
def get_suggested_class_tags(request):
    # Parse request data
    request_json = request.get_json()
    class_name = request_json.get('className')
    class_description = request_json.get('description')
    
    # Combine text for embedding
    combined_text = f"{class_name}. {class_description}"
    
    try:
        # Generate embedding using OpenAI
        embedding = openai_client.embeddings.create(
            input=combined_text,
            model="text-embedding-3-small"
        ).data[0].embedding
        
        # Query Pinecone for similar tags
        results = index.query(
            vector=embedding,
            top_k=20,
            include_metadata=True
        )
        
        # Format results
        suggested_tags = [
            {
                'id': match.id,
                'tag': match.metadata['tag'],
                'score': match.score
            }
            for match in results.matches
        ]
                
        return https_fn.Response(
            json.dumps({'suggestions': suggested_tags}),
            headers=cors_headers,
            content_type='application/json'
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({{'error': str(e)}}),
            status=500,
            headers=cors_headers,
            content_type='application/json'
        )
```

### 2. Frontend Implementation

#### A. Create Tag Suggestion Provider
Create a new provider to manage tag suggestions state and API calls:

```dart
// lib/src/features/class_creation/data/providers/tag_suggestions_provider.dart

final tagSuggestionsProvider = AsyncNotifierProvider<TagSuggestionsNotifier, List<TagData>>(() {
  return TagSuggestionsNotifier();
});

class TagSuggestionsNotifier extends AsyncNotifier<List<TagData>> {
  Future<List<TagData>> getSuggestions(String className, String description) async {
    state = const AsyncValue.loading();
    try {
      final suggestions = await _fetchSuggestions(className, description);
      state = AsyncValue.data(suggestions);
      return suggestions;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
  
  Future<List<TagData>> _fetchSuggestions(String className, String description) async {
    // Implement API call to Firebase Function
  }
}
```

#### B. Modify InterestsScreen
Update the interests screen to:
1. Accept class creation context
2. Show loading state while fetching suggestions
3. Display suggested tags first
4. Maintain existing functionality for manual tag selection, including the expansion of even suggested tags
5. Don't show duplicate tags, if they are already in the suggested list at the beginning, don't show them in the next set of tags

Key modifications needed:
- Add a "Suggested Tags" section at the top
- Allow easy selection of suggested tags
- Maintain the existing tag browsing functionality

### 3. Integration Points

1. Update the class creation flow to pass class name and description to InterestsScreen
2. Modify InterestsScreen constructor to accept class creation context
3. Add logic to trigger tag suggestions when entering from class creation flow
4. Implement proper error handling and loading states

### 4. UI/UX Considerations

1. Show suggested tags in a separate section with a clear heading
2. Use visual indicators (like badges or icons) to distinguish suggested tags
3. Consider showing confidence scores for suggested tags
4. Provide clear feedback during loading states
5. Maintain existing tag selection behavior

### 5. Testing Requirements

1. Unit tests for tag suggestion provider
2. Integration tests for API communication
3. UI tests for suggested tags display
4. Error handling tests
5. Performance testing for suggestion latency

### 6. Security Considerations

1. Rate limiting for the suggestion API
2. Input validation and sanitization
3. Proper error handling to prevent data leaks
4. Authentication checks

## Next Steps

1. Review and approve this implementation plan
2. Set up the Firebase Function endpoint
3. Implement the frontend changes
4. Add tests
5. Deploy and monitor performance

## Notes

- The existing Pinecone setup from `create_tag_embeddings.py` will be leveraged
- The same embedding model (text-embedding-3-small) will be used for consistency
- Consider caching suggestions if the same class name/description is used multiple times
- Monitor API usage for both OpenAI and Pinecone 