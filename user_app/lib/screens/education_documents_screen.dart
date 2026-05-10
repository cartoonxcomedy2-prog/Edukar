import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/education_widgets.dart';

class EducationDocumentsScreen extends StatelessWidget {
  const EducationDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eduSlate100,
      appBar: AppBar(
        title: const Text(
          'Education Documents',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: eduSlate900,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: eduSlate900,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth > 600 ? 24.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 800 ? 800 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select a section to manage your documents:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: eduSlate600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _NavCard(
                    title: 'Section 1: Personal & ID Info',
                    icon: Icons.person_outline_rounded,
                    onTap: () => Navigator.pushNamed(context, '/edu-personal'),
                  ),
                  const SizedBox(height: 12),
                  
                  _NavCard(
                    title: 'Section 2: School (Matric)',
                    icon: Icons.school_outlined,
                    onTap: () => Navigator.pushNamed(context, '/edu-matric'),
                  ),
                  const SizedBox(height: 12),
                  
                  _NavCard(
                    title: 'Section 3: College (Intermediate)',
                    icon: Icons.account_balance_outlined,
                    onTap: () => Navigator.pushNamed(context, '/edu-inter'),
                  ),
                  const SizedBox(height: 12),
                  
                  _NavCard(
                    title: "Section 4: Bachelor's",
                    icon: Icons.workspace_premium_outlined,
                    onTap: () => Navigator.pushNamed(context, '/edu-bach'),
                  ),
                  const SizedBox(height: 12),
                  
                  _NavCard(
                    title: "Section 5: Master's",
                    icon: Icons.workspace_premium_outlined,
                    onTap: () => Navigator.pushNamed(context, '/edu-master'),
                  ),
                  
                  const SizedBox(height: 24),
                  const EduRequirementsNote(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: eduSlate200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: eduGreenBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(icon, color: eduGreen, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF10231A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: eduSlate400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}