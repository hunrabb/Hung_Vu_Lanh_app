import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_routes.dart';
import '../application/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // read lấy controller để gọi logic, không đăng ký rebuild tại đây.
    final auth = context.read<AuthController>();
    if (auth.isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // Sau await, chỉ dùng context nếu màn hình vẫn còn tồn tại.
    if (!mounted) return;

    final user = auth.currentUser;
    if (success && user != null) {
      // Vai trò lấy từ tài khoản; Navigator gọi router đã đăng ký trong app.
      Navigator.of(context).pushReplacementNamed(AppRoutes.homeFor(user.role));
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  // Rounded, softly filled fields share the same visual style.
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
    // watch cập nhật giao diện khi controller thông báo thay đổi trạng thái.
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
                      'Welcome Back',
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
                      'A little time for yourself.\nSign in to plan your next visit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF756B63),
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      enabled: !auth.isLoading,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: _fieldDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Please enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      enabled: !auth.isLoading,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
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
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password.';
                        }
                        return null;
                      },
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
                        // Chặn nhấn nhiều lần và hiển thị loading từ state Auth.
                        onPressed: auth.isLoading ? null : _login,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7B6756),
                                  semanticsLabel: 'Logging in',
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.register);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF594536),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Don't have an account? Register",
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
