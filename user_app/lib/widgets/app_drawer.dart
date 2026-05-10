import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // ✅ Instant Feedback & Smooth Navigation Logic
  void _handleNavigation(BuildContext context, String routeName) {
    HapticFeedback.lightImpact(); // Click hote hi vibration taake delay feel na ho
    Navigator.pop(context); // Drawer ko pehle band karo (Essential for smooth back button)

    // Education page heavy hota hai, is liye animation khatam hone ka wait lazmi hai
    Future.delayed(const Duration(milliseconds: 250), () {
      if (context.mounted) {
        Navigator.pushNamed(context, routeName);
      }
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text('Are you sure you want to logout from your session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAIChatBox(BuildContext context) {
    _handleNavigation(context, '/ai-chat');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.75,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Header Section ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2E8B57),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      ApiService.currentUser?['name']?[0]?.toUpperCase() ?? 'G',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2E8B57)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ApiService.currentUser?['name'] ?? 'Guest User',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      Text(
                        ApiService.currentUser?['email'] ?? 'Welcome to UniApp',
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Menu Items Section ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  _drawerListTile(context, Icons.person_outline_rounded, 'My Account', () => _handleNavigation(context, '/my-account')),
                  _drawerListTile(context, Icons.description_outlined, 'Education Document', () => _handleNavigation(context, '/education-documents')),
                  _drawerListTile(context, Icons.track_changes_rounded, 'Track Application', () => _handleNavigation(context, '/track-application')),
                  _drawerListTile(context, Icons.smart_toy_outlined, 'EduKar Assistant', () => _showAIChatBox(context)),
                  _drawerListTile(context, Icons.verified_user_outlined, 'Terms and Conditions', () => _handleNavigation(context, '/terms')),

                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),

                  _drawerListTile(context, Icons.info_outline_rounded, 'About Us', () => _handleNavigation(context, '/about-us')),
                  _drawerListTile(context, Icons.help_outline_rounded, 'FAQ', () => _handleNavigation(context, '/faq')),
                  _drawerListTile(context, Icons.contact_support_outlined, 'Contact Us', () => _handleNavigation(context, '/help')),

                  const SizedBox(height: 10),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerListTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      leading: Icon(icon, color: const Color(0xFF64748B), size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}