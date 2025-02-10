import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';

class TagData {
  final String id;
  final String tag;
  final List<String> relatedTags;

  TagData({
    required this.id,
    required this.tag,
    required this.relatedTags,
  });

  String get normalizedTag => tag.replaceFirst(RegExp(r'^#'), '').toLowerCase();

  factory TagData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TagData(
      id: doc.id,
      tag: data['tag'] as String,
      relatedTags: List<String>.from(data['relatedTags'] ?? []),
    );
  }

  factory TagData.fromRelatedTag(String tag) {
    return TagData(
      id: tag.replaceFirst(RegExp(r'^#'), '').toLowerCase(),
      tag: tag,
      relatedTags: [],
    );
  }
}

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final Set<String> _selectedInterests = {};
  List<TagData> _availableTags = [];
  bool _isLoading = false;
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _fetchTags();
  }

  Future<void> _fetchTags() async {
    try {
      final tagsSnapshot = await FirebaseFirestore.instance
          .collection('videoTags')
          .orderBy('count', descending: true)
          .limit(50)
          .get();

      setState(() {
        _availableTags = tagsSnapshot.docs
            .map((doc) => TagData.fromFirestore(doc))
            .toList();
        _isLoadingTags = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoadingTags = false);
    }
  }

  Future<void> _handleTagSelection(String tag, bool selected) async {
    if (selected) {
      setState(() {
        _selectedInterests.add(tag.toLowerCase());
      });
      
      // First check if we already have the tag's data with related tags
      var selectedTagData = _availableTags
          .where((t) => t.normalizedTag == tag.toLowerCase())
          .firstOrNull;
      
      // If we don't have related tags (it was a related tag itself), fetch from Firestore
      if (selectedTagData?.relatedTags.isEmpty ?? false) {
        try {
          final tagDoc = await FirebaseFirestore.instance
              .collection('videoTags')
              .doc(tag.toLowerCase())
              .get();
          
          if (tagDoc.exists) {
            final newTagData = TagData.fromFirestore(tagDoc);
            // Update the tag in our list with the full data
            final index = _availableTags.indexWhere((t) => t.normalizedTag == tag.toLowerCase());
            if (index != -1) {
              setState(() {
                _availableTags[index] = newTagData;
              });
              selectedTagData = newTagData;
            }
          }
        } catch (e) {
          print('Error fetching related tags: $e');
        }
      }
      
      if (selectedTagData != null) {
        setState(() {
          // Find the index of the selected tag
          final selectedIndex = _availableTags.indexOf(selectedTagData!);
          
          // Add each related tag right after the selected tag
          final relatedTagsToAdd = <TagData>[];
          for (final relatedTag in selectedTagData.relatedTags) {
            final normalizedRelatedTag = relatedTag.replaceFirst(RegExp(r'^#'), '').toLowerCase();
            
            if (!_availableTags.any((t) => t.normalizedTag == normalizedRelatedTag)) {
              relatedTagsToAdd.add(TagData.fromRelatedTag(relatedTag));
            }
          }
          
          if (relatedTagsToAdd.isNotEmpty) {
            _availableTags.insertAll(selectedIndex + 1, relatedTagsToAdd);
          }
        });
      }
    } else {
      setState(() {
        _selectedInterests.remove(tag.toLowerCase());
      });
    }
  }

  Future<void> _saveInterests() async {
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(currentUserProvider)?.uid;
      if (userId == null) throw Exception('User not found');

      // Convert selected interests into a Map<String, num>
      final tagPreferences = Map.fromEntries(
        _selectedInterests.map((tag) => MapEntry(tag, 1)),
      );

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'tagPreferences': tagPreferences,
        'onboardingCompleted': true,
      });

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving interests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Interests'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What interests you?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select topics you\'d like to see content about',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingTags)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags.map((tagData) {
                    final displayTag = tagData.tag.replaceFirst(RegExp(r'^#'), '');
                    final isSelected = _selectedInterests.contains(tagData.normalizedTag);
                    
                    return FilterChip(
                      label: Text(displayTag),
                      selected: isSelected,
                      onSelected: (selected) => _handleTagSelection(displayTag, selected),
                      labelStyle: TextStyle(
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveInterests,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Finish Setup'),
            ),
          ),
        ],
      ),
    );
  }
}
