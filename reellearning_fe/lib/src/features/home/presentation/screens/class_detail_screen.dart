import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/data/providers/auth_provider.dart';
import '../../../auth/data/providers/user_provider.dart';
import '../../data/models/class_model.dart';
import '../../data/providers/class_provider.dart';
import '../../../videos/data/providers/video_provider.dart';
import '../widgets/feed_selection_pill.dart';

class ClassDetailScreen extends ConsumerWidget {
  final String classId;

  const ClassDetailScreen({
    super.key,
    required this.classId,
  });

  Widget _buildCreatorInfo(
      BuildContext context, WidgetRef ref, DocumentReference creatorRef) {
    final userData = ref.watch(userDataProvider(creatorRef));

    return userData.when(
      data: (data) => GestureDetector(
        onTap: () => context.go('/profile/${creatorRef.id}'),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: data['avatarUrl'] != null
                  ? NetworkImage(data['avatarUrl'])
                  : null,
              child:
                  data['avatarUrl'] == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['displayName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Creator'),
              ],
            ),
          ],
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading creator info'),
    );
  }

  Widget _buildJoinLeaveButton(
      BuildContext context, WidgetRef ref, ClassModel classModel) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    // Check if user is the creator
    if (classModel.creator.id == currentUser.uid) {
      return const SizedBox.shrink(); // Don't show button for creator
    }

    final isMember = ref.watch(isClassMemberProvider(classId));
    final classActions = ref.read(classActionsProvider);

    return isMember.when(
      data: (isCurrentlyMember) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            try {
              if (isCurrentlyMember) {
                await classActions.leaveClass(classId);
              } else {
                await classActions.joinClass(classId);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: isCurrentlyMember
              ? ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(isCurrentlyMember ? 'Leave Class' : 'Join Class'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error checking membership')),
    );
  }

  Widget _buildShowFeedButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Set the channel ID to this class's ID
          ref.read(currentChannelIdProvider.notifier).state = classId;
          ref.read(selectedFeedProvider.notifier).state = classId;
          // Refresh the video feed
          ref.read(paginatedVideoProvider.notifier).refresh();
          // Navigate to home screen
          context.go('/');
        },
        icon: const Icon(Icons.play_circle_outline, color: Colors.white),
        label: const Text('Show Feed'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBookmarksButton(BuildContext context, String className) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go(
          '/classes/$classId/bookmarked',
          extra: {'className': className},
        ),
        icon: const Icon(Icons.bookmark_outline, color: Colors.white),
        label: Text('$className Bookmarks'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = FirebaseFirestore.instance;
    final classDoc = firestore.collection('classes').doc(classId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: classDoc.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(
              child: Text('Class not found'),
            );
          }

          final classModel = ClassModel.fromMap(classId, data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: classModel.thumbnail.isNotEmpty
                        ? Image.network(
                            classModel.thumbnail,
                            fit: BoxFit.cover,
                          )
                        : const Center(child: Icon(Icons.class_, size: 48)),
                  ),
                ),
                const SizedBox(height: 16),

                // Class Title
                Text(
                  classModel.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Creator Info
                _buildCreatorInfo(context, ref, classModel.creator),
                const SizedBox(height: 16),

                // Class Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      'Members',
                      classModel.memberCount.toString(),
                      onTap: () => context.go(
                        '/classes/${classModel.id}/members',
                        extra: {'className': classModel.title},
                      ),
                    ),
                    _buildStat(
                      'Created',
                      classModel.createdAt.toLocal().toString().split(' ')[0],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  classModel.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Buttons section
                if (classModel.creator.id == ref.watch(currentUserProvider)?.uid) ...[
                  // Creator buttons
                  _buildShowFeedButton(context, ref),
                  const SizedBox(height: 8),
                  _buildBookmarksButton(context, classModel.title),
                  const SizedBox(height: 8),
                  _buildProgressReportButton(context, classModel.title),
                ] else ...[
                  // Non-creator buttons
                  _buildShowFeedButton(context, ref),
                  const SizedBox(height: 8),
                  _buildBookmarksButton(context, classModel.title),
                  const SizedBox(height: 8),
                  _buildJoinLeaveButton(context, ref, classModel),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressReportButton(BuildContext context, String className) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go(
          '/classes/$classId/progress',
        ),
        icon: const Icon(Icons.bar_chart, color: Colors.white),
        label: Text('$className Progress'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
