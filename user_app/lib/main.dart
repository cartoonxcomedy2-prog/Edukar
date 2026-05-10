import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/my_account_screen.dart';
import 'screens/education_documents_screen.dart';
import 'screens/track_application_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_us_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/student_tech_assistant_screen.dart';

import 'screens/edu_personal_info_screen.dart';
import 'screens/edu_matric_screen.dart';
import 'screens/edu_intermediate_screen.dart';
import 'screens/edu_bachelor_screen.dart';
import 'screens/edu_master_screen.dart';

import 'services/api_service.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  // 1. Mandatory Flutter Bindings
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 2. Preserve Splash so it doesn't flicker while we load the session
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 3. FAST SESSION RECOVERY (Before UI build)
  // This is vital so the splash screen knows immediately whether to go to home or login.
  try {
    await ApiService.fastInit().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('FastInit is taking longer than expected...');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 4. Launch branded splash route first
  runApp(const UniApp(initialRoute: '/splash'));

  // 5. BACKGROUND INITIALIZATION (Fully Isolated & Non-blocking)
  _onStartup();
}

void _onStartup() {
  // Use a short delay to allow Flutter to finish its first few frames
  Future.delayed(const Duration(milliseconds: 800), () {
    // 6. FORCE REMOVE NATIVE SPLASH
    FlutterNativeSplash.remove();

    // 7. Initialize services without blocking startup rendering.
    unawaited(_initializeServices());
  });
}

Future<void> _initializeServices() async {
  try {
    await NotificationService.init();
    // Start data sync immediately with no artificial delay.
    // The old 2-second delay caused notifications and real-time data
    // to arrive very late after app launch.
    unawaited(ApiService.init());
    unawaited(BackgroundFetchService.initializeService());
  } catch (e) {
    debugPrint('Core Init Failed: $e');
  }
}

class UniApp extends StatefulWidget {
  const UniApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  State<UniApp> createState() => _UniAppState();
}

class _UniAppState extends State<UniApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ApiService.syncAllUserData());
      unawaited(ApiService.refreshCatalogIfStale());
      unawaited(ApiService.startRealtimeSync());
    } else if (state == AppLifecycleState.paused) {
      unawaited(BackgroundFetchService.scheduleQuickSync());
    } else if (state == AppLifecycleState.detached) {
      ApiService.stopRealtimeSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduKar',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final constrainedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.92,
          maxScaleFactor: 1.0,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: constrainedScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E8B57),
          primary: const Color(0xFF2E8B57),
          brightness: Brightness.light,
        ),
        fontFamily: GoogleFonts.manrope().fontFamily,
        scaffoldBackgroundColor: Colors.white,
        // Eliminate splash overhead for instant tap response
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2E8B57), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E8B57),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textTheme: GoogleFonts.manropeTextTheme().copyWith(
          headlineLarge: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
          headlineMedium: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFF334155)),
          bodyMedium: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        useMaterial3: true,
      ),
      initialRoute: widget.initialRoute,
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/splash': (context) => const SplashScreen(nextRoute: '/login'),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const MainNavigation(),
          '/my-account': (context) => const MyAccountScreen(),
          '/education-documents': (context) => const EducationDocumentsScreen(),
          '/track-application': (context) => const TrackApplicationScreen(),
          '/faq': (context) => const FaqScreen(),
          '/terms': (context) => const TermsScreen(),
          '/help': (context) => const HelpScreen(),
          '/about-us': (context) => const AboutUsScreen(),
          '/edu-personal': (context) => const EduPersonalInfoScreen(),
          '/edu-matric': (context) => const EduMatricScreen(),
          '/edu-inter': (context) => const EduIntermediateScreen(),
          '/edu-bach': (context) => const EduBachelorScreen(),
          '/edu-master': (context) => const EduMasterScreen(),
          '/ai-chat': (context) => const EduKarAssistantScreen(),
        };
        final builder = routes[settings.name];
        if (builder == null) return null;
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // remove glow for smoother feel
  }
}
