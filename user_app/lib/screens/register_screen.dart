import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      UiHelper.showCustomSnackBar(
        context,
        'Please accept Terms & Conditions to continue.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
      );

      await ApiService.logout();

      if (!mounted) return;
      setState(() => _loading = false);
      FocusScope.of(context).unfocus();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Registration Complete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account was created successfully. Please sign in now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  child: const Text('Go to Login'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        final lower = msg.toLowerCase();
        final isOffline =
            lower.contains('no internet') ||
            lower.contains('network') ||
            lower.contains('unreachable') ||
            lower.contains('offline') ||
            lower.contains('connection timeout') ||
            lower.contains('connection error') ||
            lower.contains('connection') ||
            lower.contains('socket');
        UiHelper.showCustomSnackBar(
          context,
          isOffline
              ? 'No internet connection. Please check your network and try again.'
              : msg,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: UiHelper.responsivePadding(
            context,
            horizontal: 28,
            vertical: 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: UiHelper.scale(context, 62),
                    height: UiHelper.scale(context, 62),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E8B57), Color(0xFF3BAA6E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        UiHelper.scale(context, 18),
                      ),
                    ),
                    child: Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                      size: UiHelper.scale(context, 30),
                    ),
                  ),
                ),
                SizedBox(height: UiHelper.scale(context, 16)),
                Center(
                  child: Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: UiHelper.responsiveFontSize(context, 28),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Full name, email, mobile and password',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: UiHelper.responsiveFontSize(context, 14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: UiHelper.scale(context, 32)),

                _buildLabel('Full Name'),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Muhammad Ali',
                    hintStyle: TextStyle(
                      fontSize: UiHelper.responsiveFontSize(context, 14),
                    ),
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      size: UiHelper.scale(context, 20),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 15),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                SizedBox(height: UiHelper.scale(context, 18)),

                _buildLabel('Email Address'),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                  decoration: InputDecoration(
                    hintText: 'example@email.com',
                    hintStyle: TextStyle(
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

                _buildLabel('Mobile Number'),
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    hintText: '03XXXXXXXXX',
                    hintStyle: TextStyle(
                      fontSize: UiHelper.responsiveFontSize(context, 14),
                    ),
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      size: UiHelper.scale(context, 20),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 15),
                  ),
                  validator: (v) {
                    final input = (v ?? '').trim();
                    if (input.isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (input.length < 10) {
                      return 'Enter a valid mobile number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: UiHelper.scale(context, 18)),

                _buildLabel('Password'),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                  decoration: InputDecoration(
                    hintText: 'Minimum 6 characters',
                    hintStyle: TextStyle(
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 15),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                SizedBox(height: UiHelper.scale(context, 18)),

                _buildLabel('Confirm Password'),
                TextFormField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocus,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onFieldSubmitted: (_) => _loading ? null : _register(),
                  decoration: InputDecoration(
                    hintText: 'Re-enter password',
                    hintStyle: TextStyle(
                      fontSize: UiHelper.responsiveFontSize(context, 14),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_reset_rounded,
                      size: UiHelper.scale(context, 20),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: UiHelper.scale(context, 20),
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 15),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: UiHelper.scale(context, 12)),

                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      activeColor: const Color(0xFF2E8B57),
                      onChanged: (v) =>
                          setState(() => _acceptedTerms = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: const Color(0xFF475569),
                              fontSize: UiHelper.responsiveFontSize(
                                context,
                                13,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: const TextStyle(
                                  color: Color(0xFF2E8B57),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/terms'),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: Color(0xFF2E8B57),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: UiHelper.scale(context, 24)),
                SizedBox(
                  width: double.infinity,
                  height: UiHelper.scale(context, 54).clamp(48.0, 60.0),
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _register();
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: UiHelper.responsiveFontSize(
                                context,
                                16,
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(height: UiHelper.scale(context, 20)),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: UiHelper.responsiveFontSize(context, 14),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            'Sign In',
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
                ),
                SizedBox(height: UiHelper.scale(context, 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: UiHelper.responsiveFontSize(context, 13),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
