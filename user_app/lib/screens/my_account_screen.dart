import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _emailFocusNode;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _passwordFocusNode;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    final user = ApiService.currentUser;
    _nameController = TextEditingController(text: user?['name'] ?? '');
    _emailController = TextEditingController(text: user?['email'] ?? '');
    _phoneController = TextEditingController(text: user?['phone'] ?? '');
    _passwordController = TextEditingController();
    _nameFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      _applyUser(ApiService.currentUser, keepFocusedField: true);
    });
    _syncProfile();
  }

  Future<void> _syncProfile() async {
    try {
      await ApiService.syncAllUserData();
      _applyUser(ApiService.currentUser);
    } catch (_) {}
  }

  void _applyUser(
    Map<String, dynamic>? user, {
    bool keepFocusedField = false,
  }) {
    if (!mounted || user == null) return;
    setState(() {
      if (!keepFocusedField || !_nameFocusNode.hasFocus) {
        _nameController.text = user['name'] ?? '';
      }
      if (!keepFocusedField || !_emailFocusNode.hasFocus) {
        _emailController.text = user['email'] ?? '';
      }
      if (!keepFocusedField || !_phoneFocusNode.hasFocus) {
        _phoneController.text = user['phone'] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ApiService.currentUser;
    final hasNameChanged = _nameController.text.trim() != (user?['name'] ?? '');
    final hasEmailChanged =
        _emailController.text.trim() != (user?['email'] ?? '');
    final hasPasswordChanged = _passwordController.text.trim().isNotEmpty;

    if (!hasNameChanged && !hasEmailChanged && !hasPasswordChanged) {
      _showInfoPopup(
        title: 'No Changes',
        message: 'No updates detected in My Account.',
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFF64748B),
        buttonText: 'Back',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2E8B57).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF2E8B57),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm Changes?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Do you want to save these account updates?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _performUpdate();
  }

  Future<void> _performUpdate() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim().isNotEmpty
            ? _passwordController.text.trim()
            : null,
      );

      if (!mounted) return;
      _passwordController.clear();

      _showInfoPopup(
        title: 'Saved Successfully',
        message: 'Your account changes have been saved.',
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF10B981),
        buttonText: 'Great',
      );
    } catch (e) {
      if (mounted) {
        UiHelper.showCustomSnackBar(
          context,
          'Error: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _showInfoPopup({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String buttonText,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
        title: Text(
          'My Account',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: UiHelper.responsiveFontSize(context, 20),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ApiService.fetchProfile(forceRefresh: true);
          _applyUser(ApiService.currentUser);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: UiHelper.responsivePadding(
            context,
            horizontal: 24,
            vertical: 24,
          ).copyWith(bottom: 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: RepaintBoundary(
                    child: Container(
                      width: UiHelper.scale(context, 100),
                      height: UiHelper.scale(context, 100),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E8B57), Color(0xFF3BAA6E)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2E8B57,
                            ).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          ApiService.currentUser?['name'] != null &&
                                  ApiService.currentUser!['name'].isNotEmpty
                              ? ApiService.currentUser!['name'][0]
                                    .toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: UiHelper.responsiveFontSize(
                              context,
                              38,
                            ),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: UiHelper.scale(context, 28)),

                Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 18),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 18),

                _buildTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  focusNode: _nameFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Email Address',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  focusNode: _emailFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  focusNode: _phoneFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Password (optional)',
                      style: TextStyle(
                        fontSize: UiHelper.responsiveFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _saveChanges(),
                      scrollPadding: const EdgeInsets.only(bottom: 160),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                        fontSize: UiHelper.responsiveFontSize(context, 15),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                        hintText: 'Enter new password',
                        hintStyle: TextStyle(
                          fontSize: UiHelper.responsiveFontSize(context, 14),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (value.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: UiHelper.responsivePadding(
          context,
          horizontal: 24,
          vertical: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: UiHelper.scale(context, 54).clamp(48.0, 60.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: UiHelper.responsiveFontSize(context, 16),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: UiHelper.responsiveFontSize(context, 14),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          scrollPadding: const EdgeInsets.only(bottom: 160),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
            fontSize: UiHelper.responsiveFontSize(context, 15),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
            hintText: 'Enter $label',
            hintStyle: TextStyle(
              fontSize: UiHelper.responsiveFontSize(context, 14),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }
            if (label == 'Email Address' && !value.contains('@')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }
}
