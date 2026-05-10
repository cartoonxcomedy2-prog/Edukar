import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import 'notification_screen.dart';
import 'scholarship_screen.dart';
import 'home_screen.dart';
import 'university_screen.dart';
import '../widgets/app_drawer.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const Color _navBg = Color(0xFFEAF7EE);
  static const Color _navBorder = Color(0xFFBFDCC8);
  static const Color _navSelected = Color(0xFF1C5E3D);
  static const Color _navUnselected = Color(0xFF5F7E6E);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 2; // Default starting tab: Home

  late final List<Widget> _screens;
  StreamSubscription? _updateSubscription;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _networkBusySubscription;
  bool _isOffline = false;
  bool _isBuffering = false;
  int _lastUnreadCount = 0;
  bool _isHandlingSessionExpiry = false;
  Timer? _connectivityDebounce;
  DateTime? _lastOfflineAt;

  @override
  void initState() {
    super.initState();
    _lastUnreadCount = ApiService.unreadNotificationsCount;
    _isBuffering = ApiService.isNetworkBusy;

    _screens = [
      const UniversityScreen(), // Index 0
      const ScholarshipScreen(), // Index 1
      HomeScreen(
        onTabChange: (index) {
          if (mounted) {
            setState(() => _currentIndex = index);
            if (index == 3) {
              ApiService.markAllNotificationsAsRead();
              _lastUnreadCount = 0;
            }
          }
        },
      ), // Index 2
      const NotificationScreen(), // Index 3
    ];

    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      if (!mounted) return;
      if (!ApiService.hasActiveSession) {
        if (_isHandlingSessionExpiry) return;
        _isHandlingSessionExpiry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        });
        return;
      }
      _isHandlingSessionExpiry = false;
      final nextCount = ApiService.unreadNotificationsCount;
      if (nextCount != _lastUnreadCount) {
        setState(() => _lastUnreadCount = nextCount);
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _handleConnectivity(results, showSnack: true);
    });

    _networkBusySubscription = ApiService.onNetworkBusy.listen((busy) {
      if (!mounted || _isBuffering == busy) return;
      setState(() => _isBuffering = busy);
    });

    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty ||
          results.every((result) => result == ConnectivityResult.none)) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        final retry = await Connectivity().checkConnectivity();
        _handleConnectivity(retry, showSnack: false);
        return;
      }
      _handleConnectivity(results, showSnack: false);
    } catch (_) {}
  }

  void _handleConnectivity(
    List<ConnectivityResult> results, {
    required bool showSnack,
  }) {
    if (!mounted) return;
    
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final isOfflineNow = !hasConnection;
    
    _connectivityDebounce?.cancel();
    
    if (isOfflineNow) {
      // Debounce offline state to avoid flickering during network handovers
      _connectivityDebounce = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (!_isOffline) {
          setState(() => _isOffline = true);
          _lastOfflineAt = DateTime.now();
        }
      });
    } else {
      final wasOffline = _isOffline;
      if (wasOffline) {
        setState(() => _isOffline = false);
      }
      
      if (showSnack && wasOffline) {
        // Only show "Restored" if we were actually offline for more than 1 second
        final offlineDuration = _lastOfflineAt != null 
            ? DateTime.now().difference(_lastOfflineAt!) 
            : Duration.zero;
            
        if (offlineDuration.inMilliseconds >= 1000) {
          _showConnectivitySnackBar(false);
        }
      }
    }
  }

  void _showConnectivitySnackBar(bool isOffline) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              isOffline ? 'You are offline' : 'Internet restored',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: isOffline
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _networkBusySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          if (_isBuffering)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 2.4,
                color: Color(0xFF2E8B57),
                backgroundColor: Color(0xFFE2E8F0),
              ),
            ),
          if (_isOffline)
            Positioned(
              left: 14,
              right: 14,
              bottom: 88,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No internet connection. Please reconnect.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      endDrawer: const AppDrawer(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navBg,
          border: const Border(top: BorderSide(color: _navBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 4) {
              _scaffoldKey.currentState?.openEndDrawer();
            } else {
              if (index == 3 && _currentIndex != 3) {
                ApiService.markAllNotificationsAsRead();
                if (_lastUnreadCount != 0) {
                  setState(() => _lastUnreadCount = 0);
                }
              }
              setState(() => _currentIndex = index);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: _navBg,
          selectedItemColor: _navSelected,
          unselectedItemColor: _navUnselected,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          iconSize: 24,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance_rounded),
              label: 'Universities',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school_rounded),
              label: 'Scholarships',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text('$_lastUnreadCount'),
                isLabelVisible: _lastUnreadCount > 0,
                backgroundColor: const Color(0xFFEF4444),
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: const Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_rounded),
              label: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}
