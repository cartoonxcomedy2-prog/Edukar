import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FAQ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqItem(
            'How do I apply for a scholarship?',
            'You can apply for a scholarship by navigating to the "Scholarships" section, selecting a scholarship that interests you, and clicking the "Apply Now" button after reviewing the details.',
          ),
          _buildFaqItem(
            'What documents are required?',
            'Commonly required documents include educational transcripts, ID proof, and recommendation letters. You can upload and manage these in the "Education Document" section.',
          ),
          _buildFaqItem(
            'How can I track my application status?',
            'Go to the "Track Application" section in the menu to see the real-time status of all your submitted applications.',
          ),
          _buildFaqItem(
            'Can I edit my profile?',
            'Yes, you can update your personal information and contact details in the "My Account" section.',
          ),
          _buildFaqItem(
            'Is there a deadline for applications?',
            'Each university and scholarship has its own deadline. Please check the individual detail pages for specific dates.',
          ),
          _buildFaqItem(
            'Who can I contact for technical support?',
            'If you experience any technical issues, please visit the "Help & Support" page or contact us via the "Contact Us" section.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
