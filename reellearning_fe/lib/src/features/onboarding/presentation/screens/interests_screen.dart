import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/class_creation/data/providers/tag_suggestions_provider.dart';
import 'package:reellearning_fe/src/features/home/data/providers/class_provider.dart';

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
  final String? className;
  final String? classDescription;
  final bool isClassCreation;

  const InterestsScreen({
    super.key,
    this.className,
    this.classDescription,
    this.isClassCreation = false,
  });

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
    // Use addPostFrameCallback to ensure state modifications happen after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    if (widget.isClassCreation && widget.className != null && widget.classDescription != null) {
      // Get tag suggestions for class creation
      try {
        final suggestions = await ref.read(tagSuggestionsProvider.notifier)
            .getSuggestions(widget.className!, widget.classDescription!);
        if (mounted) {
          setState(() {
            _availableTags = suggestions;
          });
          // After getting suggestions, fetch additional tags
          await _fetchTags();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading tag suggestions: $e'),
              backgroundColor: Colors.red,
            ),
          );
          // Fall back to regular tag loading
          await _fetchTags();
        }
      }
    } else {
      // Regular onboarding flow
      await _fetchTags();
    }
  }

  Future<void> _fetchTags() async {
    try {
      final tagsSnapshot = await FirebaseFirestore.instance
          .collection('videoTags')
          .orderBy('count', descending: true)
          .limit(50)
          .get();

      final allTags = tagsSnapshot.docs
          .map((doc) => TagData.fromFirestore(doc))
          .toList();

      // If we're in class creation mode and have suggested tags,
      // filter out any duplicates from allTags and take only 30
      if (widget.isClassCreation && _availableTags.isNotEmpty) {
        final suggestedTagIds = _availableTags.map((t) => t.normalizedTag).toSet();
        final uniqueAdditionalTags = allTags
            .where((tag) => !suggestedTagIds.contains(tag.normalizedTag))
            .take(30)
            .toList();
        
        setState(() {
          _availableTags = [..._availableTags, ...uniqueAdditionalTags];
          _isLoadingTags = false;
        });
      } else {
        setState(() {
          _availableTags = allTags.take(50).toList();
          _isLoadingTags = false;
        });
      }
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

      if (widget.isClassCreation) {
        if (widget.className == null || widget.classDescription == null) {
          throw Exception('Class name and description are required');
        }

        // Create the class
        final createClass = ref.read(createClassProvider);
        final classModel = await createClass(
          title: widget.className!,
          description: widget.classDescription!,
          isPublic: true, // Default to public for now
        );

        // Create classVector document with tag preferences
        await FirebaseFirestore.instance
            .collection('classVectors')
            .doc(classModel.id)
            .set({
          'class': FirebaseFirestore.instance.collection('classes').doc(classModel.id),
          'tagPreferences': tagPreferences,
        });

        if (mounted) {
          context.go('/classes/${classModel.id}');
        }
      } else {
        // Regular onboarding flow
        final batch = FirebaseFirestore.instance.batch();

        // Update user document to mark onboarding as complete
        batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
          'onboardingCompleted': true,
        });

        // Get or create user vector document
        final userVectorRef = FirebaseFirestore.instance.collection('userVectors').doc(userId);
        final userVectorDoc = await userVectorRef.get();

        if (!userVectorDoc.exists) {
          // Initialize only tag preferences, vector will be added on first like
          batch.set(userVectorRef, {
            'user': FirebaseFirestore.instance.collection('users').doc(userId),
            'tagPreferences': tagPreferences,
          });
        } else {
          // If vector document exists, update tag preferences
          final existingTagPrefs = (userVectorDoc.data()?['tagPreferences'] as Map<String, dynamic>?) ?? {};
          final updatedTagPrefs = Map<String, num>.from(existingTagPrefs);
          
          // Add new tag preferences
          for (final tag in _selectedInterests) {
            updatedTagPrefs[tag] = (updatedTagPrefs[tag] ?? 0) + 1;
          }

          batch.update(userVectorRef, {
            'tagPreferences': updatedTagPrefs,
          });
        }

        await batch.commit();

        if (mounted) {
          context.go('/');
        }
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
        title: Text(widget.isClassCreation ? 'Select Class Topics' : 'Select Your Interests'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isClassCreation
                      ? 'What topics does your class cover?'
                      : 'What interests you?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isClassCreation
                      ? 'Select topics that students will learn about in your class'
                      : 'Select topics you\'d like to see content about',
                  style: const TextStyle(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tagData) {
                        final displayTag = tagData.tag.replaceFirst(RegExp(r'^#'), '');
                        final isSelected = _selectedInterests.contains(tagData.normalizedTag);
                        
                        return FilterChip(
                          label: Text(displayTag),
                          selected: isSelected,
                          onSelected: (selected) => _handleTagSelection(displayTag, selected),
                          labelStyle: const TextStyle(
                            fontSize: 13,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
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
                  : Text(widget.isClassCreation ? 'Continue' : 'Finish Setup'),
            ),
          ),
        ],
      ),
    );
  }
}
