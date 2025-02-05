import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = userId == null || userId == currentUser?.uid;
    final userIdToShow = userId ?? currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: userIdToShow == null
          ? const Center(child: Text('No user found'))
          : _UserProfileContent(
              userId: userIdToShow,
              isOwnProfile: isOwnProfile,
            ),
    );
  }
}

class _UserProfileContent extends ConsumerWidget {
  final String userId;
  final bool isOwnProfile;

  const _UserProfileContent({
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final profile = userData['profile'] as Map<String, dynamic>? ?? {};
        final createdAt = userData['createdAt'] as Timestamp?;
        final memberSince = createdAt != null
            ? DateFormat.yMMMd().format(createdAt.toDate())
            : 'Unknown';

        return SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Profile Image
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: profile['avatarUrl'] != null
                          ? NetworkImage(profile['avatarUrl'])
                          : null,
                      child: profile['avatarUrl'] == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Display Name
                    Text(
                      profile['displayName'] ?? 'No Name',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    
                    // Member Since
                    Text(
                      'Member since: $memberSince',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Biography
                    Text(
                      profile['biography'] ?? 'No biography',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    if (isOwnProfile) ...[
                      _buildOwnProfileActions(context, ref),
                    ] else ...[
                      _buildOtherProfileActions(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOwnProfileActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/edit');
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/videos');
          },
          icon: const Icon(Icons.video_library),
          label: const Text('Posted Videos'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/liked-videos');
          },
          icon: const Icon(Icons.favorite),
          label: const Text('Liked Videos'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/bookmarked');
          },
          icon: const Icon(Icons.bookmark),
          label: const Text('Bookmarked'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _handleLogout(context, ref),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 45),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherProfileActions(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement friend action
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friend'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement block action
              },
              icon: const Icon(Icons.block),
              label: const Text('Block'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/${userId}/videos');
          },
          icon: const Icon(Icons.video_library),
          label: const Text('Posted Videos'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/${userId}/liked-videos');
          },
          icon: const Icon(Icons.favorite),
          label: const Text('Liked Videos'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/${userId}/bookmarked');
          },
          icon: const Icon(Icons.bookmark),
          label: const Text('Bookmarked'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            context.go('/profile/${userId}/classes');
          },
          icon: const Icon(Icons.class_),
          label: const Text('View Classes'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 45),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 