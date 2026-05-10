import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      final lower = msg.toLowerCase();
      final isNetworkIssue =
          lower.contains('no internet') ||
          lower.contains('network') ||
          lower.contains('connection') ||
          lower.contains('socket') ||
          lower.contains('timeout') ||
          lower.contains('unreachable');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetworkIssue
                ? 'No internet connection. Please check your network and try again.'
                : msg,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: UiHelper.responsivePadding(context, horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: UiHelper.scale(context, 72),
                    height: UiHelper.scale(context, 72),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E8B57), Color(0xFF3BAA6E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        UiHelper.scale(context, 20),
                      ),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: UiHelper.scale(context, 36),
                    ),
                  ),
                  SizedBox(height: UiHelper.scale(context, 20)),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: UiHelper.responsiveFontSize(context, 28),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to your account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: UiHelper.responsiveFontSize(context, 14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: UiHelper.scale(context, 40)),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(
                        fontSize: UiHelper.responsiveFontSize(context, 14),
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        size: UiHelper.scale(context, 20),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: UiHelper.responsiveFontSize(context, 15),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: UiHelper.scale(context, 18)),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onFieldSubmitted: (_) => _loading ? null : _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(
                        fontSize: UiHelper.responsiveFontSize(context, 14),
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: UiHelper.scale(context, 20),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: UiHelper.scale(context, 20),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: UiHelper.responsiveFontSize(context, 15),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: UiHelper.scale(context, 32)),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: UiHelper.scale(context, 54).clamp(48.0, 60.0),
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _login();
                            },
                      child: _loading
                          ? SizedBox(
                              width: UiHelper.scale(context, 22),
                              height: UiHelper.scale(context, 22),
                              child: UiHelper.loadingIndicator(
                                size: 20,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: UiHelper.responsiveFontSize(
                                  context,
                                  16,
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: UiHelper.scale(context, 24)),

                  // Register Link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: UiHelper.responsiveFontSize(context, 14),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushReplacementNamed(context, '/register');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: const Color(0xFF2E8B57),
                              fontWeight: FontWeight.w700,
                              fontSize: UiHelper.responsiveFontSize(
                                context,
                                14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
