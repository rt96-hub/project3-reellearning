import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClassMembersScreen extends ConsumerWidget {
  final String classId;
  final String className;

  const ClassMembersScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$className Members'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: (value) {
                // TODO: Implement search functionality
              },
            ),
          ),

          // Members List
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('classMembership')
                  .where('classId', isEqualTo: FirebaseFirestore.instance.collection('classes').doc(classId))
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final memberships = snapshot.data!.docs;

                if (memberships.isEmpty) {
                  return const Center(
                    child: Text('No members found'),
                  );
                }

                return ListView.builder(
                  itemCount: memberships.length,
                  itemBuilder: (context, index) {
                    final membership = memberships[index].data() as Map<String, dynamic>;
                    final userRef = membership['userId'] as DocumentReference;

                    return FutureBuilder(
                      future: userRef.get(),
                      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(
                            leading: CircleAvatar(child: Icon(Icons.person)),
                            title: Text('Loading...'),
                          );
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        final profile = userData['profile'] as Map<String, dynamic>;
                        final displayName = profile['displayName'] ?? 'Anonymous';
                        final avatarUrl = profile['avatarUrl'];
                        final role = membership['role'] ?? 'member';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(displayName),
                          subtitle: Text(role.toString().toUpperCase()),
                          onTap: () => context.go('/profile/${userRef.id}'),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 