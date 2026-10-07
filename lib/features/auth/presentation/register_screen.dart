import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // read lấy controller để gọi đăng ký; validation chạy trước repository.
    final auth = context.read<AuthController>();
    if (auth.isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final success = await auth.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;

    if (success && auth.currentUser != null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.customerHome);
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  InputDecoration _fieldDecoration(String label, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE4DDD4)),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF756B63)),
      prefixIcon: Icon(icon, color: const Color(0xFF7B6756)),
      filled: true,
      fillColor: const Color(0xFFF3EFE9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF594536), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch cập nhật giao diện khi loading hoặc trạng thái Auth thay đổi.
    final auth = context.watch<AuthController>();
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF30251F),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(
                          Icons.content_cut,
                          size: 42,
                          color: Color(0xFFE6CCAA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'BARBERSHOP & SPA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B6756),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Join Us',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: Color(0xFF30251F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your next moment of care starts here.\nMake room for a little everyday luxury.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF756B63),
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _nameController,
                      enabled: !auth.isLoading,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập họ tên.'
                          : null,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        'Full Name',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _emailController,
                      enabled: !auth.isLoading,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Vui lòng nhập email hợp lệ.';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: _fieldDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !auth.isLoading,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập mật khẩu.'
                          : null,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration:
                          _fieldDecoration(
                            'Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: auth.isLoading
                                  ? null
                                  : () => setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    }),
                            ),
                          ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _confirmationController,
                      enabled: !auth.isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng xác nhận mật khẩu.';
                        }
                        if (value != _passwordController.text) {
                          return 'Mật khẩu xác nhận không khớp.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _register(),
                      obscureText: _obscureConfirmation,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration:
                          _fieldDecoration(
                            'Confirm Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmation
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: auth.isLoading
                                  ? null
                                  : () => setState(() {
                                      _obscureConfirmation =
                                          !_obscureConfirmation;
                                    }),
                            ),
                          ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF30251F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 19),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Khóa nút khi đang xử lý, tránh tạo tài khoản nhiều lần.
                        onPressed: auth.isLoading ? null : _register,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7B6756),
                                  semanticsLabel: 'Registering',
                                ),
                              )
                            : const Text('Register'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      // Replace the route so toggling does not stack auth screens.
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.login);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF594536),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Already have an account? Login',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
