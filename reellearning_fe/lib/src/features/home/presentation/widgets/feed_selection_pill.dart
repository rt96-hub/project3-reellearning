import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../videos/data/providers/video_provider.dart';
import '../../data/providers/class_provider.dart';

// Provider to store the currently selected feed
final selectedFeedProvider = StateProvider<String>((ref) => 'personal');

class FeedSelectionPill extends ConsumerStatefulWidget {
  final String userId;

  const FeedSelectionPill({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<FeedSelectionPill> createState() => _FeedSelectionPillState();
}

class _FeedSelectionPillState extends ConsumerState<FeedSelectionPill> {
  String? _nonMemberClassName;

  @override
  void initState() {
    super.initState();
    _updateNonMemberClassName();
  }

  @override
  void didUpdateWidget(FeedSelectionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateNonMemberClassName();
  }

  Future<void> _updateNonMemberClassName() async {
    final selectedFeed = ref.read(selectedFeedProvider);
    if (selectedFeed != 'personal') {
      // Check if this is a non-member class by looking in the memberships
      final memberships = await FirebaseFirestore.instance
          .collection('classMembership')
          .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(widget.userId))
          .where('classId', isEqualTo: FirebaseFirestore.instance.collection('classes').doc(selectedFeed))
          .get();
      
      if (memberships.docs.isEmpty) {
        // Not a member, fetch the class name
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(selectedFeed)
            .get();
        
        if (classDoc.exists && mounted) {
          final data = classDoc.data();
          if (data != null) {
            setState(() {
              _nonMemberClassName = data['title'] ?? 'Unknown Class';
            });
          }
        }
      }
    }
  }

  bool _isUserMemberOfClass(String classId, List<Map<String, dynamic>> memberClasses) {
    if (classId == 'personal') return true;
    return memberClasses.any((c) => c['id'] == classId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedFeed = ref.watch(selectedFeedProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.5,
      ),
      alignment: Alignment.center,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classMembership')
            .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(widget.userId))
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError) {
            print('Error loading class memberships: ${snapshot.error}');
            return const SizedBox.shrink();
          }

          final memberships = snapshot.data?.docs ?? [];
          
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(
              memberships.map((doc) async {
                final data = doc.data() as Map<String, dynamic>;
                final classRef = data['classId'] as DocumentReference?;
                if (classRef == null) return null;
                
                try {
                  final classDoc = await classRef.get();
                  if (!classDoc.exists) return null;
                  
                  final classData = classDoc.data() as Map<String, dynamic>?;
                  if (classData == null) return null;
                  
                  return {
                    'id': classRef.id,
                    'name': classData['title'] ?? 'Unnamed Class',
                    'isCurator': data['role'] == 'curator',
                  };
                } catch (e) {
                  print('Error loading class data: $e');
                  return null;
                }
              }),
            ).then((list) => list.whereType<Map<String, dynamic>>().toList()),
            builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> classesSnapshot) {
              if (classesSnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                );
              }

              final classes = classesSnapshot.data ?? [];
              
              // If we're viewing a non-member class, show its name but don't include it in dropdown
              String displayName;
              if (selectedFeed == 'personal') {
                displayName = 'Personal Feed';
              } else if (_nonMemberClassName != null) {
                displayName = _nonMemberClassName!;
              } else {
                final selectedClass = classes.firstWhere(
                  (c) => c['id'] == selectedFeed,
                  orElse: () => {'name': 'Loading...'},
                );
                displayName = selectedClass['name'];
              }

              // Create dropdown items
              final List<DropdownMenuItem<String>> items = [
                DropdownMenuItem(
                  value: 'personal',
                  child: _buildDropdownItem(
                    'Personal Feed',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ];

              // Add member classes to dropdown items
              for (final membership in classes) {
                items.add(
                  DropdownMenuItem(
                    value: membership['id'],
                    child: _buildDropdownItem(
                      membership['name'],
                      membership['isCurator'] ? Icons.admin_panel_settings : Icons.group,
                      membership['isCurator'] ? Colors.blue : Colors.grey,
                    ),
                  ),
                );
              }

              // If viewing a non-member class, show it in the current display but not in dropdown
              final bool isMemberOrPersonal = selectedFeed == 'personal' || 
                classes.any((c) => c['id'] == selectedFeed);

              return DropdownButtonHideUnderline(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    value: isMemberOrPersonal ? selectedFeed : null,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    dropdownColor: Colors.black.withOpacity(0.9),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    hint: _buildDropdownItem(
                      displayName,
                      Icons.group,
                      Colors.grey,
                    ),
                    items: items,
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != selectedFeed) {
                        print('[FeedSelectionPill] Switching feed from $selectedFeed to $newValue');
                        ref.read(selectedFeedProvider.notifier).state = newValue;
                        ref.read(currentChannelIdProvider.notifier).state = 
                          newValue == 'personal' ? null : newValue;
                        ref.read(paginatedVideoProvider.notifier).refresh();
                      } else {
                        print('[FeedSelectionPill] Feed $newValue already selected, skipping refresh');
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDropdownItem(String text, IconData icon, Color iconColor) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
