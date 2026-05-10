import 'package:flutter/material.dart';
import '../utils/ui_helper.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About Us',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: UiHelper.responsiveFontSize(context, 20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: UiHelper.responsivePadding(context, horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: UiHelper.scale(context, 100),
                height: UiHelper.scale(context, 100),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8B57).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: UiHelper.scale(context, 50),
                  color: const Color(0xFF2E8B57),
                ),
              ),
            ),
            SizedBox(height: UiHelper.scale(context, 24)),
            Center(
              child: Text(
                'UniApp',
                style: TextStyle(
                  fontSize: UiHelper.responsiveFontSize(context, 28),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: UiHelper.responsiveFontSize(context, 14),
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: UiHelper.scale(context, 40)),
            _buildSectionHeader(context, 'Our Mission'),
            _buildSectionBody(
              context,
              'At UniApp, we believe that education is the most powerful weapon which you can use to change the world. Our mission is to simplify the process of finding and applying for higher education and scholarships, making it accessible to every student regardless of their background.',
            ),
            SizedBox(height: UiHelper.scale(context, 24)),
            _buildSectionHeader(context, 'Our Story'),
            _buildSectionBody(
              context,
              'Founded in 2024, UniApp started as a small project to bridge the gap between students and educational institutions. Today, we are proud to help thousands of students navigate their academic journeys with ease and confidence.',
            ),
            SizedBox(height: UiHelper.scale(context, 24)),
            _buildSectionHeader(context, 'What We Offer'),
            _buildFeatureItem(context, Icons.search_rounded, 'Comprehensive University Database'),
            _buildFeatureItem(context, Icons.card_membership_rounded, 'Latest Scholarship Opportunities'),
            _buildFeatureItem(context, Icons.track_changes_rounded, 'Real-time Application Tracking'),
            _buildFeatureItem(context, Icons.folder_shared_rounded, 'Centralized Document Management'),
            SizedBox(height: UiHelper.scale(context, 40)),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '© 2026 UniApp Inc. All rights reserved.',
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: UiHelper.responsiveFontSize(context, 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: UiHelper.responsiveFontSize(context, 20),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildSectionBody(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: UiHelper.responsiveFontSize(context, 15),
        color: const Color(0xFF64748B),
        height: 1.6,
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: UiHelper.scale(context, 20), color: const Color(0xFF2E8B57)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: UiHelper.responsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
