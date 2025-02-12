import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/shared/widgets/custom_button.dart';
import 'package:reellearning_fe/src/shared/widgets/custom_text_field.dart';
import 'package:reellearning_fe/src/features/auth/data/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        await _authService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (!mounted) return;

        // Check onboarding status before navigating
        final userId = _authService.currentUser?.uid;
        if (userId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (mounted) {
            final onboardingCompleted = userDoc.data()?['onboardingCompleted'] as bool? ?? false;
            if (onboardingCompleted) {
              context.go('/');
            } else {
              context.go('/onboarding/profile');
            }
          }
        }
      } catch (e) {
        _showErrorMessage(e.toString());
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Sign In',
            onPressed: _handleSignIn,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Create Account',
            onPressed: () => context.go('/signup'),
            variant: ButtonVariant.outline,
          ),
        ],
      ),
    );
  }
} 