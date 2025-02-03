import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/shared/widgets/custom_button.dart';
import 'package:reellearning_fe/src/shared/widgets/custom_text_field.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorMessage('Passwords do not match');
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Simulate signup delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          context.go('/login');
          _showSuccessMessage();
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

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please check your email for confirmation'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Phone Number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_outlined),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: !_showPassword,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Confirm Password',
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => 
                _showConfirmPassword = !_showConfirmPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Create Account',
            onPressed: _handleSignup,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Already have an account? Sign in',
            onPressed: () => context.go('/login'),
            variant: ButtonVariant.text,
          ),
        ],
      ),
    );
  }
} 