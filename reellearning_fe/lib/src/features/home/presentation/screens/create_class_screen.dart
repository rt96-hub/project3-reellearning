import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/providers/class_provider.dart';

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

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;
  bool _showTagSelection = false;
  final Set<String> _selectedTags = {};
  List<TagData> _availableTags = [];
  bool _isLoadingTags = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchTags() async {
    setState(() => _isLoadingTags = true);
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
    } finally {
      setState(() => _isLoadingTags = false);
    }
  }

  Future<void> _handleTagSelection(String tag, bool selected) async {
    if (selected) {
      setState(() {
        _selectedTags.add(tag.toLowerCase());
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
        _selectedTags.remove(tag.toLowerCase());
      });
    }
  }

  Future<void> _proceedToTagSelection() async {
    if (!_formKey.currentState!.validate()) return;

    await _fetchTags();
    setState(() {
      _showTagSelection = true;
    });
  }

  Future<void> _createClass() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final createClass = ref.read(createClassProvider);
      final classModel = await createClass(
        title: _titleController.text,
        description: _descriptionController.text,
        isPublic: _isPublic,
      );

      // Create classVector document with tag preferences
      if (_selectedTags.isNotEmpty) {
        final tagPreferences = Map.fromEntries(
          _selectedTags.map((tag) => MapEntry(tag, 1)),
        );

        await FirebaseFirestore.instance
            .collection('classVectors')
            .doc(classModel.id)
            .set({
          'class': FirebaseFirestore.instance.collection('classes').doc(classModel.id),
          'tagPreferences': tagPreferences,
        });
      }

      if (mounted) {
        context.pop(); // Return to classes screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating class: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showTagSelection) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Class Topics'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _showTagSelection = false),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _createClass,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What topics does this class cover?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select topics that students will learn about in this class',
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
                      final isSelected = _selectedTags.contains(tagData.normalizedTag);
                      
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
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Class'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _proceedToTagSelection,
            child: const Text('Next'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Class Title',
                hintText: 'Enter a title for your class',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter a description for your class',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Public Class'),
              subtitle: Text(
                _isPublic
                    ? 'Anyone can discover and join this class'
                    : 'Only people with the link can join this class',
              ),
              value: _isPublic,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }
} 