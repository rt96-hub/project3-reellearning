import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserClassesScreen extends ConsumerWidget {
  final String userId;
  final String displayName;

  const UserClassesScreen({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$displayName\'s Classes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classMembership')
            .where('userId', isEqualTo: FirebaseFirestore.instance.collection('users').doc(userId))
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
              child: Text('Not a member of any classes'),
            );
          }

          return ListView.builder(
            itemCount: memberships.length,
            itemBuilder: (context, index) {
              final membership = memberships[index].data() as Map<String, dynamic>;
              final classRef = membership['classId'] as DocumentReference;
              final role = membership['role'] as String;

              return FutureBuilder<DocumentSnapshot>(
                future: classRef.get(),
                builder: (context, AsyncSnapshot<DocumentSnapshot> classSnapshot) {
                  if (!classSnapshot.hasData) {
                    return const ListTile(
                      title: Text('Loading...'),
                    );
                  }

                  final classData = classSnapshot.data!.data() as Map<String, dynamic>;

                  return ListTile(
                    leading: classData['thumbnail'] != null && classData['thumbnail'].isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(classData['thumbnail']),
                          )
                        : const CircleAvatar(
                            child: Icon(Icons.class_),
                          ),
                    title: Text(classData['title'] ?? 'Unnamed Class'),
                    subtitle: Text('Role: ${role.toUpperCase()}'),
                    trailing: Text('${classData['memberCount'] ?? 0} members'),
                    onTap: () => context.push('/classes/${classRef.id}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 