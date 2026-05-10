import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.nextRoute = '/login'});

  final String nextRoute;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    // Give fastInit enough time to hydrate the saved token from
    // SharedPreferences. The old 1.5s fixed delay sometimes wasn't 
    // enough on slower devices, leading to a false "no session" result
    // and sending the user back to login.
    try {
      await ApiService.fastInit().timeout(const Duration(seconds: 3));
    } catch (_) {
      // If it times out, proceed with whatever state we have.
    }

    // Minimum visual splash time so the logo is seen
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    final target = ApiService.hasActiveSession ? '/home' : widget.nextRoute;
    Navigator.pushReplacementNamed(context, target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: Image.asset(
                  'assets/branding/univsindh_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'EduKar',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bright Future',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 26),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF2E8B57),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF486252),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
