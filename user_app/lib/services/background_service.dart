import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

class BackgroundFetchService {
  static const String _taskName = 'sindh_background_sync_task';
  static const String _quickTaskName = 'sindh_background_quick_sync_task';
  static const Duration _quickSyncCooldown = Duration(minutes: 2);
  static bool _initialized = false;
  static DateTime? _lastQuickSyncAt;

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();

      try {
        await ApiService.fastInit();
        await ApiService.syncAllUserData(notifyOnBootstrap: false);
      } catch (e) {
        debugPrint('Background task warning: $e');
      }

      return Future.value(true);
    });
  }

  static Future<void> initializeService() async {
    if (_initialized) return;
    _initialized = true;

    await Workmanager().initialize(
      callbackDispatcher,
      // Keep debug notification noise disabled to avoid false "task failure"
      // popups while developing.
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      'sindh_background_sync',
      _taskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: const Duration(minutes: 1),
    );

    await ApiService.startRealtimeSync();
    debugPrint('Background sync service initialized');
  }

  static Future<void> scheduleQuickSync() async {
    if (!_initialized) return;
    if (kDebugMode) return;

    final now = DateTime.now();
    if (_lastQuickSyncAt != null &&
        now.difference(_lastQuickSyncAt!) < _quickSyncCooldown) {
      return;
    }

    try {
      await Workmanager().registerOneOffTask(
        'sindh_background_quick_sync',
        _quickTaskName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        initialDelay: const Duration(seconds: 8),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      _lastQuickSyncAt = now;
    } catch (e) {
      debugPrint('Quick background sync schedule warning: $e');
    }
  }
}
