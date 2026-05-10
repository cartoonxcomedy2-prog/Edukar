import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'notification_service.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      validateStatus: (status) => (status ?? 500) < 500,
    ),
  );

  static const String _tokenKey = 'token';
  static const String _cacheUserKey = 'api_current_user';
  static const String _cacheBannersKey = 'api_banners';
  static const String _cacheUniversitiesKey = 'api_universities';
  static const String _cacheScholarshipsKey = 'api_scholarships';
  static const String _cacheNotificationsKey = 'api_notifications';
  static const String _cacheMetaKey = 'api_cache_meta';

  static bool _hasResolvedReachableBaseUrl = false;
  static bool _isResolvingBaseUrl = false;
  static bool _isHydratedFromCache = false;
  static bool _isSyncingUserData = false;
  static String? _token;

  static Timer? _realtimeTimer;
  static int _realtimeTick = 0;
  static const Duration _realtimePollInterval = Duration(seconds: 8);
  static DateTime _lastCatalogRefreshAt = DateTime.fromMillisecondsSinceEpoch(
    0,
  );
  static const Duration _catalogRefreshCooldown = Duration(minutes: 1);
  static List<dynamic> _notifications = [];
  static List<String> _knownNotificationFingerprints = [];
  static bool _hasCompletedNotificationBootstrap = false;
  static Timer? _updateEmitTimer;
  static bool _updateQueued = false;
  static int _activeRequestCount = 0;
  static bool _isNetworkBusy = false;
  static Map<String, int> _cacheMeta = {};
  static final Set<String> _backgroundRefreshInFlight = <String>{};

  static const Duration _catalogCacheTtl = Duration(minutes: 6);
  static const Duration _userProfileCacheTtl = Duration(minutes: 2);
  static const Duration _notificationsCacheTtl = Duration(seconds: 6);
  static const int _maxPdfBytes = 9 * 1024 * 1024;

  static String get baseUrl =>
      _dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '');

  static List<dynamic> allBanners = [];
  static List<dynamic> allUniversities = [];
  static List<dynamic> allScholarships = [];
  static List<String> appliedOpportunityIds = [];
  static Map<String, dynamic>? currentUser;
  static int unreadNotificationsCount = 0;

  static final _updateController = StreamController<void>.broadcast();
  static final _networkBusyController = StreamController<bool>.broadcast();
  static Stream<void> get onDataUpdated => _updateController.stream;
  static Stream<bool> get onNetworkBusy => _networkBusyController.stream;
  static bool get isNetworkBusy => _isNetworkBusy;
  static bool get hasActiveSession => _hasToken;

  static Future<void> fastInit() async {
    if (_isHydratedFromCache) return;

    await _hydrateCachedState();
    // Intentionally omitting _ensureWorkingBaseUrl here so splash screen is instant!
    _isHydratedFromCache = true;
  }

  static Future<void> init() async {
    debugPrint('ApiService: initializing data sync...');
    await fastInit();
    await _ensureWorkingBaseUrl(silent: true);

    try {
      await Future.wait([
        fetchBanners(forceRefresh: true),
        fetchUniversities(forceRefresh: true),
        fetchScholarships(forceRefresh: true),
      ]);
    } catch (e) {
      debugPrint('ApiService init public sync warning: $e');
    }

    if (_hasToken) {
      await syncAllUserData();
      await startRealtimeSync();
    }
  }

  static bool get _hasToken => _token != null && _token!.trim().isNotEmpty;

  static int _cacheTimestampMs(String key) {
    return _cacheMeta[key] ?? 0;
  }

  static bool _isCacheFresh(String key, Duration ttl) {
    final updatedAt = _cacheTimestampMs(key);
    if (updatedAt <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch - updatedAt <=
        ttl.inMilliseconds;
  }

  static void _touchCache(String key) {
    _cacheMeta[key] = DateTime.now().millisecondsSinceEpoch;
  }

  static void _scheduleBackgroundRefresh(
    String key,
    Future<void> Function() task,
  ) {
    if (_backgroundRefreshInFlight.contains(key)) return;
    _backgroundRefreshInFlight.add(key);
    unawaited(
      task().whenComplete(() {
        _backgroundRefreshInFlight.remove(key);
      }),
    );
  }

  static Future<void> syncAllUserData({bool notifyOnBootstrap = false}) async {
    if (!_hasToken || _isSyncingUserData) return;

    _isSyncingUserData = true;
    try {
      final previousProfileFp = _profileFingerprint(currentUser);
      final previousNotificationsFp = listFingerprint(_notifications);
      final previousApplications = _toList(currentUser?['applications']);
      Map<String, dynamic>? profile;
      List<dynamic>? notifications;

      try {
        final profileRes = await _requestWithAutoRetry(
          () => _dio.get('users/profile'),
        );
        if (await _expireSessionIfUnauthorizedStatus(profileRes.statusCode)) {
          return;
        }
        if ((profileRes.statusCode ?? 500) < 400 &&
            profileRes.data is Map<String, dynamic>) {
          profile = Map<String, dynamic>.from(profileRes.data);
        }
      } catch (e) {
        debugPrint('Sync profile warning: $e');
      }

      try {
        final notifRes = await _requestWithAutoRetry(
          () => _dio.get('users/notifications'),
        );
        if (await _expireSessionIfUnauthorizedStatus(notifRes.statusCode)) {
          return;
        }
        if ((notifRes.statusCode ?? 500) >= 400) {
          return;
        }
        final notifRaw = notifRes.data is Map<String, dynamic>
            ? notifRes.data['data']
            : notifRes.data;
        notifications = _toList(notifRaw);
      } catch (e) {
        debugPrint('Sync notifications warning: $e');
      }

      if (profile != null) {
        profile = await _expandProfileApplications(profile);
        final nextApps = _toList(profile['applications']);
        profile['applications'] = _mergeApplicationsById(
          nextApps,
          previousApplications,
        );
        currentUser = profile;

        final applications = _toList(profile['applications']);
        appliedOpportunityIds = _extractAppliedIds(applications);
      }

      final nextNotifications =
          notifications ?? _toList(profile?['notifications']);
      bool notificationsChanged = false;
      if (nextNotifications.isNotEmpty || _notifications.isNotEmpty) {
        notificationsChanged = await _consumeNotifications(
          nextNotifications,
          forceNotify: notifyOnBootstrap,
        );
      } else {
        _hasCompletedNotificationBootstrap = true;
      }

      final profileChanged =
          _profileFingerprint(currentUser) != previousProfileFp;
      final notificationsFp = listFingerprint(_notifications);
      final notificationsFingerprintChanged =
          notificationsFp != previousNotificationsFp;
      final didChange =
          profileChanged ||
          notificationsChanged ||
          notificationsFingerprintChanged;

      if (didChange) {
        await _persistCurrentState();
        _emitDataUpdated();
      }
    } finally {
      _isSyncingUserData = false;
    }
  }

  static Future<void> startRealtimeSync() async {
    if (!_hasToken) return;

    _realtimeTimer?.cancel();
    _realtimeTick = 0;
    _realtimeTimer = Timer.periodic(_realtimePollInterval, (_) {
      unawaited(_runRealtimeSyncTick());
    });
    unawaited(_runRealtimeSyncTick());
  }

  static void stopRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
    _realtimeTick = 0;
  }

  static Future<void> _runRealtimeSyncTick() async {
    // NOTE: Removed the _isSyncingUserData guard here — it caused missed
    // ticks and delayed notification delivery. syncAllUserData already has
    // its own internal guard so double-execution is impossible.
    try {
      _realtimeTick++;
      final shouldFullSync =
          currentUser == null ||
          _realtimeTick % 3 == 0 ||
          _notifications.isEmpty;
      if (shouldFullSync) {
        await syncAllUserData();
      } else {
        await _syncNotificationsOnly();
      }
    } catch (e) {
      debugPrint('Realtime sync warning: $e');
    }
  }

  static Future<void> logout() async {
    stopRealtimeSync();
    _updateEmitTimer?.cancel();
    _updateQueued = false;
    _token = null;
    _dio.options.headers.remove('Authorization');

    currentUser = null;
    appliedOpportunityIds = [];
    unreadNotificationsCount = 0;
    _notifications = [];
    _knownNotificationFingerprints = [];
    _hasCompletedNotificationBootstrap = false;
    _cacheMeta = {};

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_cacheUserKey);
    await prefs.remove(_cacheNotificationsKey);
    await prefs.remove(_cacheMetaKey);

    _emitDataUpdated();
    debugPrint('Logged out');
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final hasTransport = await _hasAnyNetworkTransport();
    if (!hasTransport) {
      throw Exception(_friendlyConnectionMessage());
    }

    final response = await _requestWithAutoRetry(
      () => _dio.post(
        'users/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
        options: Options(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 12),
        ),
      ),
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        _extractErrorMessage(response.data, fallback: 'Login failed'),
      );
    }

    await _applyAuthPayload(response.data);
    unawaited(syncAllUserData());
    unawaited(startRealtimeSync());
  }

  static Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final hasTransport = await _hasAnyNetworkTransport();
    if (!hasTransport) {
      throw Exception(_friendlyConnectionMessage());
    }

    final response = await _requestWithAutoRetry(
      () => _dio.post(
        'users',
        data: {
          'name': name,
          'email': email.trim().toLowerCase(),
          'password': password,
          'phone': phone,
        },
      ),
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        _extractErrorMessage(response.data, fallback: 'Registration failed'),
      );
    }

    await _applyAuthPayload(response.data);
    unawaited(syncAllUserData());
    unawaited(startRealtimeSync());
  }

  static Future<void> refreshCatalogIfStale({bool force = false}) async {
    final now = DateTime.now();
    final isFresh =
        now.difference(_lastCatalogRefreshAt) < _catalogRefreshCooldown;
    if (!force && isFresh) return;

    _lastCatalogRefreshAt = now;
    try {
      await Future.wait([
        fetchUniversities(forceRefresh: true),
        fetchScholarships(forceRefresh: true),
        fetchBanners(forceRefresh: true),
      ]);
    } catch (e) {
      debugPrint('Catalog refresh warning: $e');
    }
  }

  static Future<List<dynamic>> fetchBanners({bool forceRefresh = false}) async {
    if (!forceRefresh && allBanners.isNotEmpty) {
      if (_isCacheFresh(_cacheBannersKey, _catalogCacheTtl)) {
        return allBanners;
      }
      _scheduleBackgroundRefresh(_cacheBannersKey, () async {
        await fetchBanners(forceRefresh: true);
      });
      return allBanners;
    }

    try {
      final res = await _requestWithAutoRetry(() => _dio.get('banners'));
      final data = _toList(res.data);
      var changed = false;
      if (data.isNotEmpty || forceRefresh) {
        final previous = listFingerprint(allBanners);
        allBanners = data;
        changed = listFingerprint(allBanners) != previous;
        await _persistList(_cacheBannersKey, allBanners);
      }
      _touchCache(_cacheBannersKey);
      await _persistCacheMeta();
      if (changed) {
        _emitDataUpdated();
      }
      return allBanners;
    } catch (e) {
      debugPrint('Fetch banners warning: $e');
      return allBanners;
    }
  }

  static Future<List<dynamic>> fetchUniversities({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && allUniversities.isNotEmpty) {
      if (_isCacheFresh(_cacheUniversitiesKey, _catalogCacheTtl)) {
        return allUniversities;
      }
      _scheduleBackgroundRefresh(_cacheUniversitiesKey, () async {
        await fetchUniversities(forceRefresh: true);
      });
      return allUniversities;
    }

    try {
      final res = await _requestWithAutoRetry(() => _dio.get('universities'));
      final data = _toList(res.data);
      var changed = false;
      if (data.isNotEmpty || forceRefresh) {
        final previous = listFingerprint(allUniversities);
        allUniversities = data;
        changed = listFingerprint(allUniversities) != previous;
        await _persistList(_cacheUniversitiesKey, allUniversities);
      }
      _touchCache(_cacheUniversitiesKey);
      await _persistCacheMeta();
      if (changed) {
        _emitDataUpdated();
      }
      return allUniversities;
    } catch (e) {
      debugPrint('Fetch universities warning: $e');
      return allUniversities;
    }
  }

  static Future<List<dynamic>> fetchScholarships({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && allScholarships.isNotEmpty) {
      if (_isCacheFresh(_cacheScholarshipsKey, _catalogCacheTtl)) {
        return allScholarships;
      }
      _scheduleBackgroundRefresh(_cacheScholarshipsKey, () async {
        await fetchScholarships(forceRefresh: true);
      });
      return allScholarships;
    }

    try {
      final res = await _requestWithAutoRetry(() => _dio.get('scholarships'));
      final data = _toList(res.data);
      var changed = false;
      if (data.isNotEmpty || forceRefresh) {
        final previous = listFingerprint(allScholarships);
        allScholarships = data;
        changed = listFingerprint(allScholarships) != previous;
        await _persistList(_cacheScholarshipsKey, allScholarships);
      }
      _touchCache(_cacheScholarshipsKey);
      await _persistCacheMeta();
      if (changed) {
        _emitDataUpdated();
      }
      return allScholarships;
    } catch (e) {
      debugPrint('Fetch scholarships warning: $e');
      return allScholarships;
    }
  }

  static Future<List<dynamic>> fetchNotifications({
    bool forceRefresh = false,
  }) async {
    if (!_hasToken) return _notifications;

    if (!forceRefresh && _notifications.isNotEmpty) {
      if (_isCacheFresh(_cacheNotificationsKey, _notificationsCacheTtl)) {
        return _notifications;
      }
      _scheduleBackgroundRefresh(_cacheNotificationsKey, () async {
        await _refreshNotificationsFromNetwork();
      });
      return _notifications;
    }

    await _refreshNotificationsFromNetwork();
    return _notifications;
  }

  static Future<void> _refreshNotificationsFromNetwork() async {
    try {
      final previousFingerprint = listFingerprint(_notifications);
      final res = await _requestWithAutoRetry(
        () => _dio.get('users/notifications'),
      );
      if (await _expireSessionIfUnauthorizedStatus(res.statusCode)) {
        return;
      }
      if ((res.statusCode ?? 500) >= 400) {
        return;
      }
      final data = _toList(
        res.data is Map<String, dynamic> ? res.data['data'] : res.data,
      );
      final changed = await _consumeNotifications(data);
      final currentFingerprint = listFingerprint(_notifications);
      _touchCache(_cacheNotificationsKey);
      await _persistCacheMeta();
      if (changed || previousFingerprint != currentFingerprint) {
        await _persistCurrentState();
        _emitDataUpdated();
      }
    } catch (e) {
      debugPrint('Fetch notifications warning: $e');
    }
  }

  static Future<Map<String, dynamic>?> fetchProfile({
    bool forceRefresh = false,
  }) async {
    if (!_hasToken) return currentUser;
    if (!forceRefresh && currentUser != null) {
      if (_isCacheFresh(_cacheUserKey, _userProfileCacheTtl)) {
        return currentUser;
      }
      _scheduleBackgroundRefresh(_cacheUserKey, () async {
        await _refreshProfileFromNetwork();
      });
      return currentUser;
    }

    await _refreshProfileFromNetwork();
    return currentUser;
  }

  static Future<void> _refreshProfileFromNetwork() async {
    if (!_hasToken) return;

    try {
      final previousFp = _profileFingerprint(currentUser);
      final previousApplications = _toList(currentUser?['applications']);
      final res = await _requestWithAutoRetry(() => _dio.get('users/profile'));
      if (await _expireSessionIfUnauthorizedStatus(res.statusCode)) {
        return;
      }
      if ((res.statusCode ?? 500) >= 400) {
        return;
      }
      if (res.data is Map<String, dynamic>) {
        currentUser = await _expandProfileApplications(
          Map<String, dynamic>.from(res.data),
        );
        currentUser!['applications'] = _mergeApplicationsById(
          _toList(currentUser!['applications']),
          previousApplications,
        );
        appliedOpportunityIds = _extractAppliedIds(
          _toList(currentUser!['applications']),
        );
        final changed = _profileFingerprint(currentUser) != previousFp;
        _touchCache(_cacheUserKey);
        await _persistCacheMeta();
        if (changed) {
          await _persistCurrentState();
          _emitDataUpdated();
        }
      }
    } catch (e) {
      debugPrint('Fetch profile warning: $e');
    }
  }

  static bool _isImageExtension(String extension) {
    const imageExts = <String>{'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    return imageExts.contains(extension.toLowerCase());
  }

  static bool _isPdfExtension(String extension) {
    return extension.toLowerCase() == '.pdf';
  }

  static String _basename(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }

  static String _sanitizeUploadFilename(
    String rawName, {
    String fallback = 'file.upload',
  }) {
    final trimmed = rawName.trim();
    final base = trimmed.split(RegExp(r'[\\/]+')).last;
    final safe = base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (safe.isEmpty) return fallback;
    if (safe.length <= 90) return safe;
    return safe.substring(safe.length - 90);
  }

  static Future<File> _compressImageForUpload(File originalFile) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}${Platform.pathSeparator}cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      originalFile.path,
      quality: 72,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (compressedBytes == null || compressedBytes.isEmpty) {
      return originalFile;
    }

    final compressedFile = File(outPath);
    await compressedFile.writeAsBytes(compressedBytes, flush: true);
    final oldSize = await originalFile.length();
    final newSize = await compressedFile.length();
    if (newSize <= 0 || newSize >= oldSize) {
      if (compressedFile.existsSync()) {
        await compressedFile.delete();
      }
      return originalFile;
    }
    return compressedFile;
  }

  static Future<File> _prepareUploadFile(File inputFile) async {
    final extension = inputFile.path.contains('.')
        ? '.${inputFile.path.split('.').last.toLowerCase()}'
        : '';

    if (_isPdfExtension(extension)) {
      final bytes = await inputFile.length();
      if (bytes > _maxPdfBytes) {
        throw Exception('PDF is too large. Upload a PDF under 9MB.');
      }
      return inputFile;
    }

    if (_isImageExtension(extension)) {
      return _compressImageForUpload(inputFile);
    }

    return inputFile;
  }

  static Future<void> updateProfile({
    String? name,
    String? fatherName,
    String? phone,
    String? email,
    String? password,
    String? dateOfBirth,
    Map<String, dynamic>? education,
    Map<String, dynamic>? files,
    String? address,
    String? state,
    String? city,
  }) async {
    if (!_hasToken) {
      throw Exception('Please login again');
    }

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (fatherName != null) payload['fatherName'] = fatherName;
    if (phone != null) payload['phone'] = phone;
    if (email != null) payload['email'] = email;
    if (password != null) payload['password'] = password;
    if (dateOfBirth != null) payload['dateOfBirth'] = dateOfBirth;
    if (address != null) payload['address'] = address;
    if (state != null) payload['state'] = state;
    if (city != null) payload['city'] = city;
    if (education != null) payload['education'] = education;

    final hasFiles =
        files != null &&
        files.entries.any((entry) {
          final value = entry.value;
          if (value == null) return false;
          if (value is Map) {
            final path = (value['path'] ?? '').toString().trim();
            final bytes = value['bytes'];
            final hasBytes = bytes is Uint8List
                ? bytes.isNotEmpty
                : bytes is List<int>
                ? bytes.isNotEmpty
                : false;
            return path.isNotEmpty || hasBytes;
          }
          return value.toString().trim().isNotEmpty;
        });

    Response response;
    if (hasFiles) {
      final formDataMap = <String, dynamic>{};
      final tempFilesToDelete = <String>[];
      final attemptedFileKeys = <String>{};
      final invalidFileKeys = <String>{};
      String? firstInvalidFileError;
      int attachedFilesCount = 0;
      for (final entry in payload.entries) {
        if (entry.value == null) continue;
        if (entry.key == 'education') {
          formDataMap['education'] = jsonEncode(entry.value);
        } else {
          formDataMap[entry.key] = entry.value;
        }
      }

      try {
        for (final entry in files.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value == null) continue;

          String filePath = '';
          String fileName = '';
          Uint8List? bytes;

          if (value is Map) {
            filePath = (value['path'] ?? '').toString().trim();
            fileName = (value['name'] ?? '').toString().trim();
            final rawBytes = value['bytes'];
            if (rawBytes is Uint8List) {
              bytes = rawBytes;
            } else if (rawBytes is List<int>) {
              bytes = Uint8List.fromList(rawBytes);
            }
          } else {
            filePath = value.toString().trim();
          }

          final hasPath = filePath.isNotEmpty;
          final hasBytes = bytes != null && bytes.isNotEmpty;
          if (!hasPath && !hasBytes) continue;
          attemptedFileKeys.add(key);

          try {
            if (hasPath) {
              final file = File(filePath);
              if (file.existsSync()) {
                final preparedFile = await _prepareUploadFile(file);
                if (preparedFile.path != file.path) {
                  tempFilesToDelete.add(preparedFile.path);
                }
                formDataMap[key] = await MultipartFile.fromFile(
                  preparedFile.path,
                  filename: _basename(preparedFile.path),
                );
                attachedFilesCount += 1;
                continue;
              }
            }

            if (hasBytes) {
              final fallbackName = fileName.isNotEmpty
                  ? fileName
                  : '$key.upload';
              final safeName = _sanitizeUploadFilename(
                fallbackName,
                fallback: '$key.upload',
              );
              final tempDir = await getTemporaryDirectory();
              final tempInputPath =
                  '${tempDir.path}${Platform.pathSeparator}upl_${DateTime.now().microsecondsSinceEpoch}_$safeName';
              final tempInputFile = File(tempInputPath);
              await tempInputFile.writeAsBytes(bytes, flush: true);
              tempFilesToDelete.add(tempInputFile.path);

              final preparedFile = await _prepareUploadFile(tempInputFile);
              if (preparedFile.path != tempInputFile.path) {
                tempFilesToDelete.add(preparedFile.path);
              }

              formDataMap[key] = await MultipartFile.fromFile(
                preparedFile.path,
                filename: _basename(preparedFile.path),
              );
              attachedFilesCount += 1;
              continue;
            }

            invalidFileKeys.add(key);
          } catch (e) {
            invalidFileKeys.add(key);
            firstInvalidFileError ??= _extractErrorMessage(
              e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
              fallback: 'Failed to process file: $key',
            );
            debugPrint('Skipping invalid file $key: $e');
          }
        }

        if (attemptedFileKeys.isNotEmpty && attachedFilesCount == 0) {
          throw Exception(
            'Selected files could not be read. Please re-select and upload again.',
          );
        }
        if (invalidFileKeys.isNotEmpty) {
          throw Exception(
            firstInvalidFileError ??
                'Some files failed to process: ${invalidFileKeys.join(', ')}',
          );
        }

        if (formDataMap.keys.length <= payload.keys.length &&
            attemptedFileKeys.isNotEmpty &&
            attachedFilesCount == 0) {
          throw Exception(
            'No valid files were attached to the upload request.',
          );
        }

        if (attachedFilesCount == 0 && attemptedFileKeys.isEmpty) {
          response = await _requestWithAutoRetry(
            () => _dio.put('users/profile', data: payload),
          );
        } else {
          response = await _requestWithAutoRetry(
            () =>
                _dio.put('users/profile', data: FormData.fromMap(formDataMap)),
          );
        }
      } finally {
        for (final tempPath in tempFilesToDelete) {
          try {
            final file = File(tempPath);
            if (file.existsSync()) {
              await file.delete();
            }
          } catch (_) {}
        }
      }
    } else {
      response = await _requestWithAutoRetry(
        () => _dio.put('users/profile', data: payload),
      );
    }

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        _extractErrorMessage(response.data, fallback: 'Profile update failed'),
      );
    }

    await syncAllUserData();
  }

  static Future<void> applyToOpportunity({
    String? scholarshipId,
    String? universityId,
    String? type,
    List<Map<String, dynamic>>? selectedPrograms,
  }) async {
    if (!_hasToken) {
      throw Exception('Please login first');
    }

    final payload = <String, dynamic>{
      'type': type,
      'selectedPrograms': selectedPrograms ?? [],
    };
    if (scholarshipId != null) payload['scholarshipId'] = scholarshipId;
    if (universityId != null) payload['universityId'] = universityId;

    final response = await _requestWithAutoRetry(
      () => _dio.post('applications/apply', data: payload),
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        _extractErrorMessage(response.data, fallback: 'Application failed'),
      );
    }

    await syncAllUserData();
  }

  static final RegExp _embeddedUrlRegExp = RegExp(
    r'https?:\/\/[^\s"<>]+',
    caseSensitive: false,
  );

  static String _extractEmbeddedRemoteUrl(String raw) {
    final match = _embeddedUrlRegExp.firstMatch(raw);
    if (match == null) return '';
    var extracted = raw.substring(match.start, match.end).trim();
    extracted = extracted.replaceFirst(RegExp(r'[\],);.]+$'), '');
    return extracted;
  }

  static String _normalizeCloudinaryDocumentUrl(String url) {
    if (url.isEmpty) return url;
    try {
      final parsed = Uri.parse(url);
      final isCloudinary = parsed.host.toLowerCase().endsWith('cloudinary.com');
      final isDocument = RegExp(
        r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|csv)$',
        caseSensitive: false,
      ).hasMatch(parsed.path);
      if (isCloudinary &&
          isDocument &&
          parsed.path.contains('/image/upload/')) {
        return url.replaceFirst('/image/upload/', '/raw/upload/');
      }
    } catch (_) {}
    return url;
  }

  static bool _isNullLikePath(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'undefined' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == 'none' ||
        normalized == '-';
  }

  static String getUploadUrl(String? path) {
    if (path == null) return '';
    final raw = path.toString().trim();
    if (_isNullLikePath(raw)) return '';

    final embeddedRemote = _extractEmbeddedRemoteUrl(raw);
    if (embeddedRemote.isNotEmpty) {
      return _normalizeCloudinaryDocumentUrl(embeddedRemote);
    }

    if (raw.startsWith('data:')) return raw;

    final host = _hostBaseUrl();

    if (raw.startsWith('/api/uploads/')) {
      return '$host${raw.replaceFirst('/api', '')}';
    }
    if (raw.startsWith('api/uploads/')) {
      return '$host/${raw.replaceFirst('api/', '')}';
    }
    if (raw.startsWith('/uploads/')) return '$host$raw';
    if (raw.startsWith('uploads/')) return '$host/$raw';

    final uploadsIndex = raw.indexOf('/uploads/');
    if (uploadsIndex >= 0) {
      return _normalizeCloudinaryDocumentUrl(
        '$host${raw.substring(uploadsIndex)}',
      );
    }

    return _normalizeCloudinaryDocumentUrl('$host/uploads/$raw');
  }

  static String getFullUrl(String? path) => getUploadUrl(path);

  static Future<Uint8List> downloadApplicationDocumentBytes({
    required String applicationId,
    required String field,
    String? universityId,
    String? downloadName,
  }) async {
    if (!_hasToken) {
      throw Exception('Please login again');
    }

    final safeField = field.trim();
    if (safeField != 'admitCard' && safeField != 'offerLetter') {
      throw Exception('Invalid document field');
    }

    Future<Uint8List> requestDoc({String? uniId}) async {
      final response = await _requestWithAutoRetry(
        () => _dio.get(
          'applications/$applicationId/download-doc/$safeField',
          queryParameters: {
            if (uniId != null && uniId.trim().isNotEmpty) 'uniId': uniId.trim(),
            if (uniId != null && uniId.trim().isNotEmpty)
              'universityId': uniId.trim(),
            if (downloadName != null && downloadName.trim().isNotEmpty)
              'downloadName': downloadName.trim(),
          },
          options: Options(responseType: ResponseType.bytes),
        ),
      );

      if ((response.statusCode ?? 500) >= 400) {
        throw Exception(
          _extractErrorMessage(
            response.data,
            fallback: 'Document download failed',
          ),
        );
      }

      final payload = response.data;
      if (payload is Uint8List) return payload;
      if (payload is List<int>) return Uint8List.fromList(payload);
      throw Exception('Unexpected download response');
    }

    final requestedUni = universityId?.trim() ?? '';
    return requestDoc(
      uniId: requestedUni.isEmpty ? null : requestedUni,
    );
  }

  static Future<Uint8List> downloadEducationDocumentBytes({
    required String userId,
    required String section,
    required String field,
    String? downloadName,
  }) async {
    if (!_hasToken) {
      throw Exception('Please login again');
    }

    final safeUserId = userId.trim();
    final safeSection = section.trim();
    final safeField = field.trim();
    if (safeUserId.isEmpty || safeSection.isEmpty || safeField.isEmpty) {
      throw Exception('Invalid education document path');
    }

    final response = await _requestWithAutoRetry(
      () => _dio.get(
        'users/$safeUserId/education/$safeSection/$safeField/download',
        queryParameters: {
          if (downloadName != null && downloadName.trim().isNotEmpty)
            'downloadName': downloadName.trim(),
        },
        options: Options(responseType: ResponseType.bytes),
      ),
    );

    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        _extractErrorMessage(
          response.data,
          fallback: 'Education document download failed',
        ),
      );
    }

    final payload = response.data;
    if (payload is Uint8List) return payload;
    if (payload is List<int>) return Uint8List.fromList(payload);
    throw Exception('Unexpected download response');
  }

  static void markAllNotificationsAsRead() {
    final updated = _notifications.map((item) {
      final map = _asMap(item);
      if (map == null) return item;
      return {...map, 'isRead': true};
    }).toList();

    _notifications = updated;
    unreadNotificationsCount = 0;
    if (currentUser != null) {
      currentUser = {...currentUser!, 'notifications': updated};
    }
    _persistCurrentState();
    _emitDataUpdated();

    if (_hasToken) {
      unawaited(_markNotificationsReadOnServer());
    }
  }

  static Future<void> _markNotificationsReadOnServer() async {
    try {
      await _requestWithAutoRetry(() => _dio.put('users/notifications/read'));
    } catch (e) {
      debugPrint('Mark notifications read warning: $e');
    }
  }

  Future<Response> post(String path, dynamic data) =>
      _requestWithAutoRetry(() => _dio.post(path, data: data));
  Future<Response> get(String path) =>
      _requestWithAutoRetry(() => _dio.get(path));

  static void _beginNetworkRequest() {
    _activeRequestCount += 1;
    if (!_isNetworkBusy) {
      _isNetworkBusy = true;
      if (!_networkBusyController.isClosed) {
        _networkBusyController.add(true);
      }
    }
  }

  static void _endNetworkRequest() {
    if (_activeRequestCount > 0) _activeRequestCount -= 1;
    if (_activeRequestCount == 0 && _isNetworkBusy) {
      _isNetworkBusy = false;
      if (!_networkBusyController.isClosed) {
        _networkBusyController.add(false);
      }
    }
  }

  static Future<T> _requestWithAutoRetry<T>(
    Future<T> Function() request,
  ) async {
    _beginNetworkRequest();
    try {
      try {
        return await request();
      } on DioException catch (e) {
        if (!_isNetworkException(e)) rethrow;

        final hasTransport = await _hasAnyNetworkTransport();
        if (!hasTransport) {
          throw Exception(_friendlyConnectionMessage());
        }

        final recovered = await _ensureWorkingBaseUrl(
          force: true,
          silent: true,
        );
        if (!recovered) {
          throw Exception(_friendlyConnectionMessage());
        }

        try {
          return await request();
        } on DioException catch (retryError) {
          if (_isNetworkException(retryError)) {
            throw Exception(_friendlyConnectionMessage());
          }
          rethrow;
        }
      }
    } finally {
      _endNetworkRequest();
    }
  }

  static Future<bool> _ensureWorkingBaseUrl({
    bool force = false,
    bool silent = false,
  }) async {
    if (_hasResolvedReachableBaseUrl && !force) return true;
    if (_isResolvingBaseUrl && !force) return _hasResolvedReachableBaseUrl;

    _isResolvingBaseUrl = true;
    try {
      final rawCandidates = <String>[
        _dio.options.baseUrl,
        ...ApiConfig.candidateBaseUrls,
      ];

      final seen = <String>{};
      final normalizedCandidates = <String>[];
      for (final raw in rawCandidates) {
        final candidate = ApiConfig.normalizeBaseUrl(raw);
        if (!seen.add(candidate)) continue;
        normalizedCandidates.add(candidate);
      }

      if (normalizedCandidates.isEmpty) {
        normalizedCandidates.add(ApiConfig.baseUrl);
      }

      final primaryCandidate = normalizedCandidates.first;
      final skipLikelyLocalFallbacks = !_isLikelyLocalBaseUrl(primaryCandidate);
      final prioritizedCandidates = <String>[
        ...normalizedCandidates.where((url) => url == primaryCandidate),
        ...normalizedCandidates.where(
          (url) => url != primaryCandidate && !_isLikelyLocalBaseUrl(url),
        ),
        ...normalizedCandidates.where(
          (url) => url != primaryCandidate && _isLikelyLocalBaseUrl(url),
        ),
      ];

      for (final candidate in prioritizedCandidates) {
        if (skipLikelyLocalFallbacks && _isLikelyLocalBaseUrl(candidate)) {
          continue;
        }

        if (await _canReach(candidate)) {
          _dio.options.baseUrl = candidate;
          _hasResolvedReachableBaseUrl = true;
          if (!silent) {
            debugPrint('API connected on: $candidate');
          }
          return true;
        }
      }

      _hasResolvedReachableBaseUrl = false;
      if (!silent) debugPrint('No reachable API base URL found.');
      return false;
    } finally {
      _isResolvingBaseUrl = false;
    }
  }

  static Future<bool> _canReach(String candidateBaseUrl) async {
    final probe = Dio(
      BaseOptions(
        baseUrl: candidateBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        validateStatus: (status) => true,
      ),
    );

    try {
      await probe.get('');
      return true;
    } on DioException catch (e) {
      return e.type == DioExceptionType.badResponse;
    } catch (_) {
      return false;
    }
  }

  static bool _isNetworkException(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  static String _hostBaseUrl() {
    final currentApiBase = _dio.options.baseUrl.isEmpty
        ? ApiConfig.baseUrl
        : _dio.options.baseUrl;
    final normalized = ApiConfig.normalizeBaseUrl(currentApiBase);
    return normalized.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _isLikelyLocalBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final host = (uri?.host ?? '').toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == '10.0.3.2';
  }

  static String _friendlyConnectionMessage() {
    return 'No internet connection. Please check your network and try again.';
  }

  static bool _isUnauthorizedStatusCode(int? statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  static Future<bool> _expireSessionIfUnauthorizedStatus(
    int? statusCode,
  ) async {
    if (!_isUnauthorizedStatusCode(statusCode)) return false;
    await logout();
    return true;
  }

  static Future<bool> _hasAnyNetworkTransport() async {
    // connectivity_plus often falsely reports no network on emulators.
    // We will let Dio throw SocketExceptions if the network is truly down.
    return true;
  }

  static Future<Map<String, dynamic>> _expandProfileApplications(
    Map<String, dynamic> profile,
  ) async {
    final applications = _toList(profile['applications']);
    final meta = _asMap(profile['applicationsMeta']);
    final hasMore = meta?['hasMore'] == true;
    if (!hasMore) {
      return {...profile, 'applications': applications};
    }

    try {
      final mergedApps = <dynamic>[...applications];
      int page = 2;
      int totalPages = 2;
      const int maxPages = 25;
      final fallbackLimit = (meta?['limit'] is num)
          ? (meta!['limit'] as num).toInt().clamp(20, 100)
          : 50;

      while (page <= totalPages && page <= maxPages) {
        final res = await _requestWithAutoRetry(
          () => _dio.get(
            'applications/me',
            queryParameters: {'page': page, 'limit': fallbackLimit},
          ),
        );

        if ((res.statusCode ?? 500) >= 400) break;

        final payload = res.data;
        if (payload is! Map<String, dynamic>) break;

        final nextBatch = _toList(payload['data']);
        final pagination = _asMap(payload['pagination']);
        if (pagination?['totalPages'] is num) {
          totalPages = (pagination!['totalPages'] as num).toInt();
        }

        if (nextBatch.isEmpty) break;
        mergedApps.addAll(nextBatch);
        page += 1;
      }

      return {
        ...profile,
        'applications': mergedApps,
        'applicationsMeta': {
          ...?meta,
          'hasMore': false,
          'loadedAllPages': true,
        },
      };
    } catch (e) {
      debugPrint('Expand applications warning: $e');
      return {...profile, 'applications': applications};
    }
  }

  static Future<void> _applyAuthPayload(dynamic payload) async {
    if (payload is! Map<String, dynamic>) {
      throw Exception('Invalid auth response from server');
    }

    final token = payload['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token missing');
    }

    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';

    final user = Map<String, dynamic>.from(payload)..remove('token');
    user['applications'] = _toList(user['applications']);
    currentUser = user;

    appliedOpportunityIds = _extractAppliedIds(_toList(user['applications']));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_cacheUserKey, jsonEncode(currentUser));
    _touchCache(_cacheUserKey);
    await _persistCurrentState();
    _emitDataUpdated();
  }

  static Future<void> _hydrateCachedState() async {
    final prefs = await SharedPreferences.getInstance();

    _token = prefs.getString(_tokenKey);
    if (_hasToken) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
    _cacheMeta = _decodeIntMap(prefs.getString(_cacheMetaKey));

    currentUser = _decodeMap(prefs.getString(_cacheUserKey));
    allBanners = _decodeList(prefs.getString(_cacheBannersKey));
    allUniversities = _decodeList(prefs.getString(_cacheUniversitiesKey));
    allScholarships = _decodeList(prefs.getString(_cacheScholarshipsKey));
    _notifications = _dedupeNotifications(
      _decodeList(
        prefs.getString(_cacheNotificationsKey),
      ).map((raw) => _asMap(raw) ?? {'title': 'Update', 'body': ''}).toList(),
    );

    if (currentUser != null) {
      currentUser!['applications'] = _toList(currentUser!['applications']);
      appliedOpportunityIds = _extractAppliedIds(
        _toList(currentUser!['applications']),
      );
      final fallbackNotifications = _toList(currentUser!['notifications']);
      if (_notifications.isEmpty && fallbackNotifications.isNotEmpty) {
        _notifications = _dedupeNotifications(
          fallbackNotifications
              .map((raw) => _asMap(raw) ?? {'title': 'Update', 'body': ''})
              .toList(),
        );
      }
    }

    unreadNotificationsCount = _notifications.where((item) {
      final map = _asMap(item);
      return map != null && map['isRead'] != true;
    }).length;

    _knownNotificationFingerprints = _notifications
        .map(_notificationSemanticKey)
        .toList();
    _hasCompletedNotificationBootstrap = _notifications.isNotEmpty;
  }

  static Future<void> _persistCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    if (currentUser != null) {
      await prefs.setString(_cacheUserKey, jsonEncode(currentUser));
      _touchCache(_cacheUserKey);
    }
    await prefs.setString(_cacheNotificationsKey, jsonEncode(_notifications));
    _touchCache(_cacheNotificationsKey);
    await _persistCacheMeta();
  }

  static Future<void> _persistList(String key, List<dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
    _touchCache(key);
    await _persistCacheMeta();
  }

  static Future<void> _persistCacheMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheMetaKey, jsonEncode(_cacheMeta));
  }

  static Future<bool> _consumeNotifications(
    List<dynamic> notifications, {
    bool forceNotify = false,
  }) async {
    final previousFingerprint = listFingerprint(_notifications);
    final localReadById = <String, bool>{};
    final localReadByFingerprint = <String, bool>{};
    for (final raw in _notifications) {
      final map = _asMap(raw);
      if (map?['isRead'] != true) continue;
      final id = map?['_id']?.toString();
      if (id != null && id.isNotEmpty) {
        localReadById[id] = true;
      }
      final fp = _notificationSemanticKey(map);
      if (fp.isNotEmpty) {
        localReadByFingerprint[fp] = true;
      }
    }

    final normalized = notifications
        .map((item) => _asMap(item) ?? {'title': 'Update', 'body': ''})
        .map((item) {
          final id = item['_id']?.toString();
          final fp = _notificationSemanticKey(item);
          if ((id != null && localReadById[id] == true) ||
              localReadByFingerprint[fp] == true) {
            return {...item, 'isRead': true};
          }
          return item;
        })
        .toList();
    final deduped = _dedupeNotifications(normalized);

    final nextFingerprints = deduped.map(_notificationSemanticKey).toList();
    final known = Set<String>.from(_knownNotificationFingerprints);
    final incoming = deduped
        .where((item) => !known.contains(_notificationSemanticKey(item)))
        .toList();

    final shouldNotifyUser = forceNotify || _hasCompletedNotificationBootstrap;

    if (shouldNotifyUser && incoming.isNotEmpty) {
      for (final item in incoming) {
        if (item['isRead'] == true) {
          continue;
        }
        await NotificationService.showNotification(
          item['title']?.toString() ?? 'Update',
          item['body']?.toString() ?? '',
        );
      }
    }

    _notifications = deduped;
    unreadNotificationsCount = deduped
        .where((item) => item['isRead'] != true)
        .length;
    _knownNotificationFingerprints = nextFingerprints;
    _hasCompletedNotificationBootstrap = true;

    if (currentUser != null) {
      currentUser = {...currentUser!, 'notifications': deduped};
    }

    final currentFingerprint = listFingerprint(_notifications);
    return previousFingerprint != currentFingerprint;
  }

  static Future<void> _syncNotificationsOnly() async {
    if (!_hasToken) return;

    try {
      final previousNotificationsFp = listFingerprint(_notifications);
      final previousProfileFp = _profileFingerprint(currentUser);

      final res = await _requestWithAutoRetry(
        () => _dio.get('users/notifications'),
      );
      if (await _expireSessionIfUnauthorizedStatus(res.statusCode)) {
        return;
      }
      if ((res.statusCode ?? 500) >= 400) {
        return;
      }
      final notifRaw = res.data is Map<String, dynamic>
          ? res.data['data']
          : res.data;
      final notifications = _toList(notifRaw);
      final notificationsChanged = await _consumeNotifications(notifications);
      _touchCache(_cacheNotificationsKey);
      await _persistCacheMeta();
      final statusPatched = _applyStatusesFromNotifications();

      final changed =
          notificationsChanged ||
          listFingerprint(_notifications) != previousNotificationsFp ||
          _profileFingerprint(currentUser) != previousProfileFp ||
          statusPatched;
      if (changed) {
        await _persistCurrentState();
        _emitDataUpdated();
      }
    } catch (e) {
      debugPrint('Realtime lightweight sync warning: $e');
    }
  }

  static const Set<String> _validApplicationStatuses = {
    'applied',
    'admit card',
    'test',
    'interview',
    'selected',
    'rejected',
  };

  static bool _isValidApplicationStatus(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return _validApplicationStatuses.contains(normalized);
  }

  static int _timestampMsFromDynamic(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 0;
    return parsed.millisecondsSinceEpoch;
  }

  static bool _applyStatusesFromNotifications() {
    final user = currentUser;
    if (user == null) return false;

    final apps = _toList(user['applications']);
    if (apps.isEmpty || _notifications.isEmpty) return false;

    final appIndexById = <String, int>{};
    for (int i = 0; i < apps.length; i++) {
      final id = apps[i]['_id']?.toString();
      if (id != null && id.isNotEmpty) {
        appIndexById[id] = i;
      }
    }

    final latestAppStatusById = <String, Map<String, dynamic>>{};
    final latestUniversityStatusByKey = <String, Map<String, dynamic>>{};

    for (final raw in _notifications) {
      final item = _asMap(raw);
      if (item == null) continue;

      final data = _asMap(item['data']);
      if (data == null || data['type']?.toString() != 'application') continue;

      final status = data['status']?.toString().trim();
      if (status == null || status.isEmpty) continue;
      if (!_isValidApplicationStatus(status)) continue;
      final notificationTs = _notificationTimestampMs(item);

      final appId = data['applicationId']?.toString().trim();
      if (appId == null || appId.isEmpty) continue;

      final notificationType =
          item['type']?.toString().trim().toLowerCase() ?? '';
      final documentLabel =
          data['documentLabel']?.toString().trim() ??
          data['docLabel']?.toString().trim() ??
          '';
      final lowerTitle = item['title']?.toString().trim().toLowerCase() ?? '';
      final lowerBody = item['body']?.toString().trim().toLowerCase() ?? '';
      final isDocumentNotification =
          notificationType == 'application-document' ||
          documentLabel.isNotEmpty ||
          lowerTitle.contains('uploaded') ||
          lowerBody.contains('uploaded');
      if (isDocumentNotification) continue;

      final universityId = data['universityId']?.toString().trim() ?? '';
      final isUniversityStatus =
          notificationType == 'application-university-status' ||
          (notificationType.isEmpty && universityId.isNotEmpty);
      final isAppStatus =
          notificationType == 'application-status' ||
          notificationType == 'application-submit' ||
          (notificationType.isEmpty && universityId.isEmpty);

      if (isUniversityStatus && universityId.isNotEmpty) {
        final key = '$appId::$universityId';
        latestUniversityStatusByKey.putIfAbsent(
          key,
          () => {'status': status, 'ts': notificationTs},
        );
        continue;
      }

      if (isAppStatus) {
        latestAppStatusById.putIfAbsent(
          appId,
          () => {'status': status, 'ts': notificationTs},
        );
      }
    }

    bool changed = false;
    latestAppStatusById.forEach((appId, payload) {
      final index = appIndexById[appId];
      if (index == null) return;

      final app = _asMap(apps[index]);
      if (app == null) return;
      final status = payload['status']?.toString().trim() ?? '';
      if (status.isEmpty) return;
      final currentStatus = app['status']?.toString().trim() ?? '';
      if (_isValidApplicationStatus(currentStatus)) return;

      final notificationTs = payload['ts'] is int ? payload['ts'] as int : 0;
      final appUpdatedAtMs = _timestampMsFromDynamic(app['updatedAt']);
      if (notificationTs > 0 && appUpdatedAtMs > notificationTs) return;
      if (currentStatus == status) return;

      final updated = <String, dynamic>{...app, 'status': status};
      apps[index] = updated;
      changed = true;
    });

    latestUniversityStatusByKey.forEach((key, payload) {
      final parts = key.split('::');
      if (parts.length != 2) return;
      final appId = parts[0];
      final uniId = parts[1];
      final index = appIndexById[appId];
      if (index == null) return;

      final app = _asMap(apps[index]);
      if (app == null) return;
      if (app['offeredUniversities'] is! List) return;
      final status = payload['status']?.toString().trim() ?? '';
      if (status.isEmpty) return;
      final notificationTs = payload['ts'] is int ? payload['ts'] as int : 0;
      final appUpdatedAtMs = _timestampMsFromDynamic(app['updatedAt']);

      final offered = _toList(app['offeredUniversities']);
      bool offeredChanged = false;
      final newOffered = offered.map((entry) {
        final itemMap = _asMap(entry);
        if (itemMap == null) return entry;
        final university = _asMap(itemMap['university']);
        final id =
            university?['_id']?.toString() ?? itemMap['university']?.toString();
        final currentStatus = itemMap['status']?.toString().trim() ?? '';
        if (id == uniId &&
            !_isValidApplicationStatus(currentStatus) &&
            (notificationTs <= 0 || appUpdatedAtMs <= notificationTs) &&
            currentStatus != status) {
          offeredChanged = true;
          return {...itemMap, 'status': status};
        }
        return itemMap;
      }).toList();

      if (offeredChanged) {
        final updated = <String, dynamic>{
          ...app,
          'offeredUniversities': newOffered,
        };
        apps[index] = updated;
        changed = true;
      }
    });

    if (changed) {
      currentUser = {...user, 'applications': apps};
      appliedOpportunityIds = _extractAppliedIds(apps);
    }
    return changed;
  }

  static String listFingerprint(List<dynamic> items) {
    if (items.isEmpty) return '0';

    final sample = <dynamic>[];
    sample.add(items.first);
    if (items.length > 2) sample.add(items[items.length ~/ 2]);
    if (items.length > 1) sample.add(items.last);

    final b = StringBuffer()..write(items.length);
    int unread = 0;
    int rolling = 0;
    for (final raw in sample) {
      final map = _asMap(raw);
      if (map == null) {
        b.write('|${raw.hashCode}');
        continue;
      }
      b
        ..write('|${map['_id'] ?? ''}')
        ..write('|${map['updatedAt'] ?? ''}')
        ..write('|${map['createdAt'] ?? ''}')
        ..write('|${map['status'] ?? ''}')
        ..write('|${map['isRead'] ?? ''}');
    }
    for (final raw in items) {
      final map = _asMap(raw);
      if (map != null) {
        if (map['isRead'] != true) unread++;
        rolling =
            (rolling * 31 + (map['_id']?.toString() ?? '').hashCode) &
            0x7fffffff;
        rolling =
            (rolling * 31 + (map['updatedAt']?.toString() ?? '').hashCode) &
            0x7fffffff;
        rolling =
            (rolling * 31 + (map['createdAt']?.toString() ?? '').hashCode) &
            0x7fffffff;
        rolling =
            (rolling * 31 + (map['status']?.toString() ?? '').hashCode) &
            0x7fffffff;
        rolling =
            (rolling * 31 + (map['isRead']?.toString() ?? '').hashCode) &
            0x7fffffff;
      } else {
        rolling = (rolling * 31 + raw.toString().hashCode) & 0x7fffffff;
      }
    }
    b
      ..write('|u:$unread')
      ..write('|h:$rolling');
    return b.toString();
  }

  static String _profileFingerprint(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final apps = _toList(profile['applications']);
    final notifications = _toList(profile['notifications']);
    return '${profile['_id'] ?? ''}|${profile['updatedAt'] ?? ''}|${profile['name'] ?? ''}|'
        '${apps.length}|${listFingerprint(apps)}|${notifications.length}|${listFingerprint(notifications)}';
  }

  static List<String> _extractAppliedIds(List<dynamic> applications) {
    final ids = <String>{};
    for (final app in applications) {
      final map = _asMap(app);
      if (map == null) continue;
      final isReapplyEligible =
          map['isReapplyEligible'] == true ||
          map['isReapplyEligible']?.toString().toLowerCase() == 'true';
      if (isReapplyEligible) continue;
      final type = map['type']?.toString().toLowerCase();
      final uni = _asMap(map['university']);
      final scholarship = _asMap(map['scholarship']);

      if (type == 'university' && uni?['_id'] != null) {
        ids.add(uni!['_id'].toString());
      } else if (type == 'scholarship' && scholarship?['_id'] != null) {
        ids.add(scholarship!['_id'].toString());
      } else {
        if (uni?['_id'] != null) ids.add(uni!['_id'].toString());
        if (scholarship?['_id'] != null) {
          ids.add(scholarship!['_id'].toString());
        }
      }
    }
    return ids.toList();
  }

  static List<dynamic> _toList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return [];
  }

  static List<dynamic> _mergeApplicationsById(
    List<dynamic> primary,
    List<dynamic> fallback,
  ) {
    if (primary.isEmpty && fallback.isEmpty) return const [];
    if (primary.isEmpty) return List<dynamic>.from(fallback);
    if (fallback.isEmpty) return List<dynamic>.from(primary);

    final fallbackById = <String, Map<String, dynamic>>{};
    final fallbackWithoutId = <dynamic>[];
    for (final raw in fallback) {
      final map = _asMap(raw);
      final id = map?['_id']?.toString().trim() ?? '';
      if (map != null && id.isNotEmpty) {
        fallbackById[id] = map;
      } else {
        fallbackWithoutId.add(raw);
      }
    }

    final merged = <dynamic>[];
    final usedIds = <String>{};

    for (final raw in primary) {
      final map = _asMap(raw);
      final id = map?['_id']?.toString().trim() ?? '';
      if (map != null && id.isNotEmpty) {
        final fallbackMatch = fallbackById[id];
        merged.add(
          fallbackMatch != null
              ? _mergeMapPreferPrimary(map, fallbackMatch)
              : map,
        );
        usedIds.add(id);
      } else {
        merged.add(raw);
      }
    }

    for (final entry in fallbackById.entries) {
      if (usedIds.contains(entry.key)) continue;
      merged.add(entry.value);
    }
    merged.addAll(fallbackWithoutId);
    return merged;
  }

  static dynamic _mergeDynamicPreferPrimary(dynamic primary, dynamic fallback) {
    if (primary is Map) {
      final pMap = Map<String, dynamic>.from(primary);
      final fMap = fallback is Map
          ? Map<String, dynamic>.from(fallback)
          : const <String, dynamic>{};
      return _mergeMapPreferPrimary(pMap, fMap);
    }
    if (primary is List) {
      final pList = List<dynamic>.from(primary);
      final fList = fallback is List ? List<dynamic>.from(fallback) : const [];
      return _mergeListPreferPrimary(pList, fList);
    }
    // Keep server value as source of truth for scalars (including empty/null).
    return primary;
  }

  static const Set<String> _appStaleSensitiveKeys = {
    'status',
    'admitCard',
    'offerLetter',
    'testDate',
    'interviewDate',
    'offeredUniversities',
  };

  static const Set<String> _offeredUniStaleSensitiveKeys = {
    'status',
    'admitCard',
    'offerLetter',
  };

  static bool _looksLikeApplicationMap(Map<String, dynamic> map) {
    return map.containsKey('type') ||
        map.containsKey('offeredUniversities') ||
        map.containsKey('admitCard') ||
        map.containsKey('offerLetter');
  }

  static bool _looksLikeOfferedUniversityMap(Map<String, dynamic> map) {
    if (!map.containsKey('university')) return false;
    return map.containsKey('status') ||
        map.containsKey('admitCard') ||
        map.containsKey('offerLetter');
  }

  static bool _shouldSkipFallbackKey({
    required Map<String, dynamic> primary,
    required Map<String, dynamic> fallback,
    required String key,
  }) {
    if (_looksLikeApplicationMap(primary) || _looksLikeApplicationMap(fallback)) {
      if (_appStaleSensitiveKeys.contains(key)) return true;
    }
    if (_looksLikeOfferedUniversityMap(primary) ||
        _looksLikeOfferedUniversityMap(fallback)) {
      if (_offeredUniStaleSensitiveKeys.contains(key)) return true;
    }
    return false;
  }

  static Map<String, dynamic> _mergeMapPreferPrimary(
    Map<String, dynamic> primary,
    Map<String, dynamic> fallback,
  ) {
    if (fallback.isEmpty) return Map<String, dynamic>.from(primary);
    if (primary.isEmpty) return Map<String, dynamic>.from(fallback);

    final result = Map<String, dynamic>.from(primary);
    for (final entry in fallback.entries) {
      final key = entry.key;
      if (!result.containsKey(key)) {
        if (_shouldSkipFallbackKey(
          primary: primary,
          fallback: fallback,
          key: key,
        )) {
          continue;
        }
        result[key] = entry.value;
        continue;
      }
      result[key] = _mergeDynamicPreferPrimary(result[key], entry.value);
    }
    return result;
  }

  static List<dynamic> _mergeListPreferPrimary(
    List<dynamic> primary,
    List<dynamic> fallback,
  ) {
    if (primary.isEmpty) return List<dynamic>.from(fallback);
    if (fallback.isEmpty) return primary;

    final fallbackByIdentity = <String, dynamic>{};
    final fallbackWithoutIdentity = <dynamic>[];
    for (final item in fallback) {
      final identity = _dynamicIdentity(item);
      if (identity == null || identity.isEmpty) {
        fallbackWithoutIdentity.add(item);
      } else {
        fallbackByIdentity[identity] = item;
      }
    }

    final merged = <dynamic>[];
    final usedIdentities = <String>{};
    for (final item in primary) {
      final identity = _dynamicIdentity(item);
      if (identity == null || identity.isEmpty) {
        merged.add(item);
        continue;
      }
      final fallbackMatch = fallbackByIdentity[identity];
      merged.add(
        fallbackMatch != null
            ? _mergeDynamicPreferPrimary(item, fallbackMatch)
            : item,
      );
      usedIdentities.add(identity);
    }

    for (final entry in fallbackByIdentity.entries) {
      if (usedIdentities.contains(entry.key)) continue;
      merged.add(entry.value);
    }
    merged.addAll(fallbackWithoutIdentity);
    return merged;
  }

  static String? _dynamicIdentity(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;
    return _mapIdentityKey(map);
  }

  static String? _mapIdentityKey(Map<String, dynamic> map) {
    final directId = map['_id']?.toString().trim() ?? '';
    if (directId.isNotEmpty) return '_id:$directId';

    final uni = _asMap(map['university']);
    final uniId =
        uni?['_id']?.toString().trim() ?? map['university']?.toString().trim();
    if (uniId != null && uniId.isNotEmpty) return 'university:$uniId';

    final scholarship = _asMap(map['scholarship']);
    final schId =
        scholarship?['_id']?.toString().trim() ??
        map['scholarship']?.toString().trim();
    if (schId != null && schId.isNotEmpty) return 'scholarship:$schId';

    final programName = (map['programName'] ?? map['name'] ?? '')
        .toString()
        .trim();
    if (programName.isNotEmpty) {
      final programType = (map['programType'] ?? map['type'] ?? '')
          .toString()
          .trim();
      final duration = (map['duration'] ?? '').toString().trim();
      return 'program:${programName.toLowerCase()}|${programType.toLowerCase()}|$duration';
    }

    return null;
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return List<dynamic>.from(decoded);
      return [];
    } catch (_) {
      return [];
    }
  }

  static Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final output = <String, int>{};
      decoded.forEach((key, value) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null && parsed > 0) {
          output[key.toString()] = parsed;
        }
      });
      return output;
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _dedupeNotifications(
    List<Map<String, dynamic>> items,
  ) {
    if (items.length <= 1) return items;

    final mergedByKey = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final key = _notificationSemanticKey(item);
      final previous = mergedByKey[key];
      if (previous == null) {
        mergedByKey[key] = item;
        continue;
      }

      final previousMs = _notificationTimestampMs(previous);
      final currentMs = _notificationTimestampMs(item);
      final latest = currentMs >= previousMs ? item : previous;
      mergedByKey[key] = {
        ...latest,
        'isRead': previous['isRead'] == true || item['isRead'] == true,
      };
    }

    final deduped = mergedByKey.values.toList();
    deduped.sort(
      (a, b) =>
          _notificationTimestampMs(b).compareTo(_notificationTimestampMs(a)),
    );
    return deduped;
  }

  static int _notificationTimestampMs(Map<String, dynamic> item) {
    final updated = DateTime.tryParse(item['updatedAt']?.toString() ?? '');
    if (updated != null) return updated.millisecondsSinceEpoch;
    final created = DateTime.tryParse(item['createdAt']?.toString() ?? '');
    if (created != null) return created.millisecondsSinceEpoch;
    return 0;
  }

  static String _notificationSemanticKey(dynamic rawItem) {
    final item = _asMap(rawItem) ?? {};
    final data = _asMap(item['data']);
    final reminderKey = data?['reminderKey']?.toString().trim() ?? '';
    if (reminderKey.isNotEmpty) {
      return 'reminder:$reminderKey';
    }

    final type =
        data?['type']?.toString().trim() ??
        item['type']?.toString().trim() ??
        '';
    final appId = data?['applicationId']?.toString().trim() ?? '';
    final entityType =
        data?['entityType']?.toString().trim() ??
        item['entityType']?.toString().trim() ??
        '';
    final entityId =
        data?['entityId']?.toString().trim() ??
        item['entityId']?.toString().trim() ??
        '';
    final status =
        data?['status']?.toString().trim() ??
        item['status']?.toString().trim() ??
        '';

    if (appId.isNotEmpty) {
      return 'app:$appId:$type:$entityType:$entityId:$status';
    }

    final title = item['title']?.toString().trim() ?? '';
    final body = item['body']?.toString().trim() ?? '';
    final createdAt = item['createdAt']?.toString().trim() ?? '';
    return '$type|$entityType|$entityId|$status|$title|$body|$createdAt';
  }

  static Future<Map<String, dynamic>> sendChatMessage(String message) async {
    final response = await _dio.post('chat', data: {'message': message});
    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        _extractErrorMessage(response.data, fallback: 'Chat failed'),
      );
    }
    return Map<String, dynamic>.from(response.data);
  }

  static String _extractErrorMessage(dynamic raw, {required String fallback}) {
    if (raw == null) return fallback;

    if (raw is Uint8List || raw is List<int>) {
      try {
        final decoded = utf8.decode(
          raw is Uint8List ? raw : Uint8List.fromList(List<int>.from(raw)),
          allowMalformed: true,
        );
        return _extractErrorMessage(decoded, fallback: fallback);
      } catch (_) {
        return fallback;
      }
    }

    String? pickFromMap(Map<String, dynamic> map) {
      final direct = map['message']?.toString().trim();
      if (direct != null && direct.isNotEmpty) return direct;

      final error = map['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      if (error is Map) {
        final nested = pickFromMap(Map<String, dynamic>.from(error));
        if (nested != null && nested.isNotEmpty) return nested;
      }

      final errors = map['errors'];
      if (errors is List && errors.isNotEmpty) {
        for (final entry in errors) {
          if (entry is String && entry.trim().isNotEmpty) {
            return entry.trim();
          }
          final entryMap = _asMap(entry);
          final candidate = entryMap?['message'] ?? entryMap?['msg'];
          if (candidate != null && candidate.toString().trim().isNotEmpty) {
            return candidate.toString().trim();
          }
        }
      }

      final data = map['data'];
      if (data is Map) {
        final nested = pickFromMap(Map<String, dynamic>.from(data));
        if (nested != null && nested.isNotEmpty) return nested;
      }

      return null;
    }

    final rawMap = _asMap(raw);
    if (rawMap != null) {
      final message = pickFromMap(rawMap);
      if (message != null && message.isNotEmpty) return message;
    }

    if (raw is String && raw.trim().isNotEmpty) {
      final text = raw.trim();
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final message = pickFromMap(Map<String, dynamic>.from(decoded));
          if (message != null && message.isNotEmpty) return message;
        }
      } catch (_) {}
      if (text.startsWith('<!doctype') || text.startsWith('<html')) {
        return fallback;
      }
      return text;
    }

    return fallback;
  }

  static void _emitDataUpdated() {
    if (_updateController.isClosed) return;
    if (_updateQueued) return;

    _updateQueued = true;
    _updateEmitTimer?.cancel();
    _updateEmitTimer = Timer(const Duration(milliseconds: 120), () {
      _updateQueued = false;
      if (_updateController.isClosed) return;
      _updateController.add(null);
    });
  }
}
