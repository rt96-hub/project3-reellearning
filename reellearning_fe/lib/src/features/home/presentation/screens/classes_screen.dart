import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/user_provider.dart';
import '../../data/models/class_model.dart';
import '../../data/providers/class_provider.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search classes...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorName(DocumentReference creatorRef) {
    final userData = ref.watch(userDataProvider(creatorRef));
    return userData.when(
      data: (data) => Text(data['displayName'] ?? 'Unknown User'),
      loading: () => const Text('Loading...'),
      error: (_, __) => const Text('Unknown User'),
    );
  }

  Widget _buildClassesTable(List<ClassModel> classes) {
    if (classes.isEmpty) {
      return const Center(
        child: Text('No classes found'),
      );
    }

    return ListView.builder(
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classData = classes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              classData.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Creator: '),
                    _buildCreatorName(classData.creator),
                  ],
                ),
                Text('Members: ${classData.memberCount ?? 0}'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/classes/${classData.id}'),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(AsyncValue<List<ClassModel>> classesValue) {
    return classesValue.when(
      data: (classes) => _buildClassesTable(classes),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: ${error.toString()}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdClasses = ref.watch(createdClassesProvider);
    final joinedClasses = ref.watch(joinedClassesProvider);
    final discoverableClasses = ref.watch(discoverableClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/classes/new'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Classes'),
            Tab(text: 'Joined Classes'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // My Classes Tab
                _buildTabContent(createdClasses),

                // Joined Classes Tab
                _buildTabContent(joinedClasses),

                // Discover Tab
                _buildTabContent(discoverableClasses),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 