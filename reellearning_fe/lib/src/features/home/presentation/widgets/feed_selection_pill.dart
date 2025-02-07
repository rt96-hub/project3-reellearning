import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  @override
  Widget build(BuildContext context) {
    final selectedFeed = ref.watch(selectedFeedProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // If no class memberships, just show personal feed
            return _buildDropdown(selectedFeed, []);
          }

          // Process class memberships
          final memberships = snapshot.data!.docs;
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
              return _buildDropdown(selectedFeed, classes);
            },
          );
        },
      ),
    );
  }

  Widget _buildDropdown(String selectedFeed, List<Map<String, dynamic>> classes) {
    return DropdownButtonHideUnderline(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          value: selectedFeed,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          dropdownColor: Colors.black.withOpacity(0.9),
          style: const TextStyle(color: Colors.white),
          items: [
            // Personal feed option
            DropdownMenuItem(
              value: 'personal',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  const Text('Personal Feed'),
                ],
              ),
            ),
            // Class feed options
            ...classes.map((membership) {
              return DropdownMenuItem(
                value: membership['id'],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (membership['isCurator'])
                      const Icon(Icons.admin_panel_settings,
                          color: Colors.blue, size: 16)
                    else
                      const Icon(Icons.group, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(membership['name']),
                  ],
                ),
              );
            }),
          ],
          onChanged: (String? newValue) {
            if (newValue != null) {
              ref.read(selectedFeedProvider.notifier).state = newValue;
              // TODO: Implement feed switching logic here
            }
          },
        ),
      ),
    );
  }
}
