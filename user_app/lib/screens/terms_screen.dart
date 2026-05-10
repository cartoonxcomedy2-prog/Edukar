import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('1. Acceptance of Terms'),
            _buildSectionBody(
              'By accessing and using UniApp, you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you must not use our services.',
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('2. Use of Service'),
            _buildSectionBody(
              'UniApp provides a platform for students to find and apply for universities and scholarships. You agree to use the service only for lawful purposes and in a way that does not infringe the rights of others.',
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('3. User Accounts'),
            _buildSectionBody(
              'You are responsible for maintaining the confidentiality of your account credentials. Any activities that occur under your account are your responsibility. Please notify us immediately of any unauthorized use.',
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('4. Data Privacy'),
            _buildSectionBody(
              'Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your personal information. By using UniApp, you consent to the collection and use of your data as described.',
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('5. Application Accuracy'),
            _buildSectionBody(
              'While we strive to provide accurate information about universities and scholarships, we cannot guarantee its complete accuracy. Users are encouraged to verify details with the respective institutions.',
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('6. Limitation of Liability'),
            _buildSectionBody(
              'UniApp shall not be liable for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use our services.',
            ),
            const SizedBox(height: 30),
            const Center(
              child: Text(
                'Last Updated: March 2026',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF64748B),
        height: 1.6,
      ),
    );
  }
}
