import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';

class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _biographyController;
  bool _isLoading = false;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _biographyController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _biographyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingUserData = true);
    
    try {
      final userId = ref.read(currentUserProvider)?.uid;
      if (userId == null) {
        setState(() => _isLoadingUserData = false);
        return;
      }

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userData.exists) {
        setState(() => _isLoadingUserData = false);
        return;
      }

      final profile = userData.data()?['profile'] as Map<String, dynamic>? ?? {};
      _displayNameController.text = profile['displayName'] ?? '';
      _biographyController.text = profile['biography'] ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(currentUserProvider)?.uid;
      if (userId == null) throw Exception('User not found');

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profile': {
          'displayName': _displayNameController.text.trim(),
          'biography': _biographyController.text.trim(),
        },
      });

      if (mounted) {
        context.go('/onboarding/interests');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
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
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome! Let\'s set up your profile.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a display name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _biographyController,
                      decoration: const InputDecoration(
                        labelText: 'Biography (Optional)',
                        border: OutlineInputBorder(),
                        helperText: 'Tell us a bit about yourself',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
