import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;

  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  late Map<String, dynamic> _app;
  String _lastAppFingerprint = '';
  bool _isRefreshing = false;
  StreamSubscription? _updateSubscription;

  bool _hasFileValue(dynamic value) {
    if (value == null) return false;
    final text = value.toString().trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower != 'null' &&
        lower != 'undefined' &&
        lower != 'n/a' &&
        lower != 'na' &&
        lower != 'none' &&
        lower != '-';
  }

  String _friendlyDownloadError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final lower = raw.toLowerCase();
    if (lower.contains('cloudinary.com') || raw.startsWith('http')) {
      return 'Document link is restricted. Please ask admin to re-upload PDF.';
    }
    if (lower.contains('document not found') ||
        lower.contains('file does not exist on server')) {
      return 'Document is not available yet. Please ask admin to re-upload it.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'Network issue while downloading. Please try again.';
    }
    return raw;
  }

  String _extractEmbeddedUrl(String? source) {
    final raw = (source ?? '').trim();
    if (raw.isEmpty) return '';
    final match = RegExp(
      r'https?:\/\/[^\s"<>]+',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return '';
    return raw
        .substring(match.start, match.end)
        .replaceFirst(RegExp(r'[\],);.]+$'), '');
  }

  List<String> _directDownloadCandidates(String? sourceFile) {
    final seen = <String>{};
    final candidates = <String>[];

    void addCandidate(String? value) {
      final trimmed = (value ?? '').trim();
      if (trimmed.isEmpty) return;
      if (seen.add(trimmed)) {
        candidates.add(trimmed);
      }
    }

    final fromApi = ApiService.getUploadUrl(sourceFile);
    addCandidate(fromApi);
    addCandidate(_extractEmbeddedUrl(sourceFile));

    for (final original in List<String>.from(candidates)) {
      try {
        final parsed = Uri.parse(original);
        final isCloudinary = parsed.host.toLowerCase().endsWith('cloudinary.com');
        final isDocument = RegExp(
          r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|csv)$',
          caseSensitive: false,
        ).hasMatch(parsed.path);
        if (isCloudinary &&
            isDocument &&
            parsed.path.contains('/image/upload/')) {
          addCandidate(original.replaceFirst('/image/upload/', '/raw/upload/'));
        }
      } catch (_) {}
    }

    return candidates
        .where(
          (value) =>
              value.startsWith('http://') || value.startsWith('https://'),
        )
        .toList();
  }

  Future<Uint8List> _downloadFromDirectUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw Exception('Invalid document link');
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('File does not exist on server');
      }
      return await consolidateHttpClientResponseBytes(response);
    } finally {
      client.close(force: true);
    }
  }

  String _sanitizeFilePart(String value, {String fallback = 'document'}) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  String _inferExtension(String? source, {String fallback = '.pdf'}) {
    final raw = (source ?? '').trim();
    if (raw.isEmpty) return fallback;

    var pathLike = raw;
    final embeddedUrl = _extractEmbeddedUrl(raw);
    if (embeddedUrl.isNotEmpty) {
      try {
        pathLike = Uri.parse(embeddedUrl).path;
      } catch (_) {
        pathLike = embeddedUrl;
      }
    }

    final dotIndex = pathLike.lastIndexOf('.');
    if (dotIndex == -1) return fallback;
    final ext = pathLike.substring(dotIndex).toLowerCase();
    if (ext.isEmpty || ext.length > 10) return fallback;
    return ext;
  }

  String _detectExtensionFromBytes(Uint8List bytes, {String fallback = '.pdf'}) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return '.pdf';
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return '.png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }

    if (bytes.length >= 6) {
      final head = String.fromCharCodes(bytes.take(6)).toUpperCase();
      if (head == 'GIF87A' || head == 'GIF89A') return '.gif';
    }

    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return '.zip';
    }

    return fallback;
  }

  String _replaceFileExtension(String fileName, String extension) {
    final safeName = fileName.trim();
    if (safeName.isEmpty) return 'document$extension';
    final safeExt = extension.startsWith('.') ? extension : '.$extension';
    final base = safeName.replaceFirst(RegExp(r'\.[^.\\/]+$'), '');
    return '$base$safeExt';
  }

  String _buildApplicationDocName({
    required String field,
    String? sourceFile,
    String? uniName,
  }) {
    final userName = ApiService.currentUser?['name']?.toString() ?? 'applicant';
    final docLabel = field == 'admitCard' ? 'admit-card' : 'offer-letter';
    final ext = _inferExtension(sourceFile, fallback: '.pdf');
    final parts = <String>[
      _sanitizeFilePart(userName, fallback: 'applicant'),
      if (uniName != null && uniName.trim().isNotEmpty)
        _sanitizeFilePart(uniName, fallback: ''),
      docLabel,
    ].where((e) => e.isNotEmpty).toList();

    return '${parts.join('-')}$ext';
  }

  Future<void> _downloadAndOpenApplicationDoc({
    required String field,
    String? sourceFile,
    String? universityId,
    String? universityName,
  }) async {
    try {
      final appId = _app['_id']?.toString() ?? '';
      if (appId.isEmpty) {
        throw Exception('Application ID missing');
      }

    final downloadName = _buildApplicationDocName(
        field: field,
        sourceFile: sourceFile,
        uniName: universityName,
      );

      Uint8List? bytes;
      try {
        bytes = await ApiService.downloadApplicationDocumentBytes(
          applicationId: appId,
          field: field,
          universityId: universityId,
          downloadName: downloadName,
        );
      } catch (error) {
        final candidates = _directDownloadCandidates(sourceFile);
        if (candidates.isEmpty) rethrow;

        Object lastError = error;
        for (final candidate in candidates) {
          try {
            bytes = await _downloadFromDirectUrl(candidate);
            break;
          } catch (directError) {
            lastError = directError;
          }
        }

        if (bytes == null) {
          throw lastError;
        }
      }

      final downloadExt = _detectExtensionFromBytes(
        bytes,
        fallback: _inferExtension(sourceFile, fallback: '.pdf'),
      );
      final resolvedDownloadName = _replaceFileExtension(
        downloadName,
        downloadExt,
      );

      final baseDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${baseDir.path}${Platform.pathSeparator}$resolvedDownloadName',
      );
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        UiHelper.showCustomSnackBar(
          context,
          'File saved: ${file.path}',
          isError: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      UiHelper.showCustomSnackBar(
        context,
        'Download failed: ${_friendlyDownloadError(e)}',
        isError: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _app = widget.application;
    _lastAppFingerprint = _appFingerprint(_app);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshApp(showLoader: false);
    });
    // Listen for background updates - ONLY update from local cache to prevent network loops
    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      _updateFromLocalCache();
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  /// Updates the local state from the already-fetched global currentUser session
  void _updateFromLocalCache() {
    if (!mounted) return;
    final allApps = ApiService.currentUser?['applications'] as List? ?? [];
    final updated = allApps.firstWhere(
      (a) => a['_id'] == _app['_id'],
      orElse: () => null,
    );
    if (updated == null) return;

    final merged = _mergeApplicationWithExisting(
      Map<String, dynamic>.from(updated),
    );
    final nextFingerprint = _appFingerprint(merged);
    if (nextFingerprint == _lastAppFingerprint) return;
    setState(() {
      _app = merged;
      _lastAppFingerprint = nextFingerprint;
    });
  }

  Map<String, dynamic> _mergeApplicationWithExisting(
    Map<String, dynamic> latest,
  ) {
    final merged = Map<String, dynamic>.from(_app);

    // Keep existing values when API omits keys, but respect explicit clears.
    latest.forEach((key, value) {
      merged[key] = value;
    });

    // If server payload omits a document key, treat it as cleared so stale
    // cached links are not shown as uploaded.
    if (!latest.containsKey('admitCard')) {
      merged.remove('admitCard');
    }
    if (!latest.containsKey('offerLetter')) {
      merged.remove('offerLetter');
    }

    for (final key in const ['university', 'scholarship']) {
      final existingMap = _asMap(_app[key]);
      final latestMap = _asMap(latest[key]);
      if (latestMap != null && existingMap != null) {
        merged[key] = {...existingMap, ...latestMap};
      } else if (latestMap == null &&
          !latest.containsKey(key) &&
          existingMap != null) {
        merged[key] = existingMap;
      }
    }

    if (latest.containsKey('offeredUniversities')) {
      merged['offeredUniversities'] = _mergeOfferedUniversities(
        latest['offeredUniversities'],
        _app['offeredUniversities'],
      );
    }
    if (!latest.containsKey('offeredUniversities') &&
        _app['offeredUniversities'] is List) {
      merged['offeredUniversities'] = _app['offeredUniversities'];
    }

    if (!latest.containsKey('testDate') && _app.containsKey('testDate')) {
      merged['testDate'] = _app['testDate'];
    }
    if (!latest.containsKey('interviewDate') &&
        _app.containsKey('interviewDate')) {
      merged['interviewDate'] = _app['interviewDate'];
    }

    return merged;
  }

  List<dynamic> _mergeOfferedUniversities(
    dynamic latestRaw,
    dynamic existingRaw,
  ) {
    final latestList = latestRaw is List ? List<dynamic>.from(latestRaw) : const [];
    final existingList = existingRaw is List
        ? List<dynamic>.from(existingRaw)
        : const [];
    if (latestList.isEmpty) return latestList;
    if (existingList.isEmpty) return latestList;

    final existingByUniId = <String, Map<String, dynamic>>{};
    for (final raw in existingList) {
      final map = _asMap(raw);
      if (map == null) continue;
      final uniMap = _asMap(map['university']);
      final uniId =
          uniMap?['_id']?.toString().trim() ??
          map['university']?.toString().trim() ??
          '';
      if (uniId.isEmpty) continue;
      existingByUniId[uniId] = map;
    }

    final merged = <dynamic>[];
    for (final raw in latestList) {
      final latest = _asMap(raw);
      if (latest == null) {
        merged.add(raw);
        continue;
      }
      final latestUniMap = _asMap(latest['university']);
      final uniId =
          latestUniMap?['_id']?.toString().trim() ??
          latest['university']?.toString().trim() ??
          '';
      if (uniId.isEmpty) {
        merged.add(latest);
        continue;
      }
      final existing = existingByUniId[uniId];
      if (existing == null) {
        merged.add(latest);
        continue;
      }
      final existingUni = _asMap(existing['university']);
      final latestUni = _asMap(latest['university']);
      final mergedEntry = <String, dynamic>{
        ...existing,
        ...latest,
        if (existingUni != null && latestUni != null)
          'university': {...existingUni, ...latestUni},
      };
      if (!latest.containsKey('admitCard')) {
        mergedEntry.remove('admitCard');
      }
      if (!latest.containsKey('offerLetter')) {
        mergedEntry.remove('offerLetter');
      }
      merged.add(mergedEntry);
    }

    // Keep only latest list from server to avoid stale universities/status/docs.
    return merged;
  }

  String _appFingerprint(Map<String, dynamic> app) {
    final offered = app['offeredUniversities'] as List? ?? const [];
    final offeredFingerprint = offered
        .map((raw) {
          final item = Map<String, dynamic>.from(raw ?? const {});
          final uni = item['university'];
          final uniId = uni is Map
              ? (uni['_id']?.toString() ?? '')
              : (uni?.toString() ?? '');
          return '$uniId:${item['status'] ?? ''}:${item['admitCard'] ?? ''}:${item['offerLetter'] ?? ''}';
        })
        .join('|');
    final uni = _asMap(app['university']);
    final scholarship = _asMap(app['scholarship']);
    return '${app['_id'] ?? ''}|${app['status'] ?? ''}|${app['updatedAt'] ?? ''}|'
        '${app['admitCard'] ?? ''}|${app['offerLetter'] ?? ''}|'
        '${app['testDate'] ?? ''}|${app['interviewDate'] ?? ''}|'
        '${uni?['updatedAt'] ?? ''}|${uni?['testDate'] ?? ''}|${uni?['interviewDate'] ?? ''}|'
        '${scholarship?['updatedAt'] ?? ''}|${scholarship?['testDate'] ?? ''}|${scholarship?['interviewDate'] ?? ''}|'
        '$offeredFingerprint';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _formatOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final ms = value > 9999999999 ? value.toInt() : (value.toInt() * 1000);
      return DateFormat('dd MMM yyyy').format(
        DateTime.fromMillisecondsSinceEpoch(ms).toLocal(),
      );
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final nested = map[r'$date'] ?? map['date'] ?? map['value'];
      return _formatOptionalDate(nested);
    }
    if (value is DateTime) {
      return DateFormat('dd MMM yyyy').format(value.toLocal());
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-') {
      return null;
    }

    final numericRaw = int.tryParse(raw);
    if (numericRaw != null) {
      final ms =
          numericRaw > 9999999999 ? numericRaw : (numericRaw * 1000);
      return DateFormat('dd MMM yyyy').format(
        DateTime.fromMillisecondsSinceEpoch(ms).toLocal(),
      );
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return DateFormat('dd MMM yyyy').format(parsed.toLocal());
    }
    const fallbackFormats = ['dd-MM-yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'];
    for (final pattern in fallbackFormats) {
      try {
        final dt = DateFormat(pattern).parseStrict(raw);
        return DateFormat('dd MMM yyyy').format(dt.toLocal());
      } catch (_) {}
    }
    return raw;
  }

  String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  dynamic _pickFromMapByKeys(dynamic source, List<String> keys) {
    if (source is! Map) return null;
    final map = Map<String, dynamic>.from(source);
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }

    final keySet = keys.map(_normalizeKey).toSet();
    for (final entry in map.entries) {
      if (!keySet.contains(_normalizeKey(entry.key))) continue;
      if (entry.value != null) return entry.value;
    }
    return null;
  }

  dynamic _pickScheduleValue({
    required Map<String, dynamic> application,
    required Map<String, dynamic> entity,
    required bool isTest,
  }) {
    final keys = isTest
        ? const [
            'testDate',
            'test_date',
            'testdate',
            'examDate',
            'exam_date',
            'entryTestDate',
            'entry_test_date',
          ]
        : const [
            'interviewDate',
            'interview_date',
            'interviewdate',
            'vivaDate',
            'viva_date',
          ];

    final direct = [
      _pickFromMapByKeys(application, keys),
      _pickFromMapByKeys(application['schedule'], keys),
      _pickFromMapByKeys(application['timeline'], keys),
      _pickFromMapByKeys(entity, keys),
      _pickFromMapByKeys(entity['schedule'], keys),
      _pickFromMapByKeys(entity['timeline'], keys),
    ];
    for (final value in direct) {
      final formatted = _formatOptionalDate(value);
      if (formatted != null && formatted.trim().isNotEmpty) {
        return value;
      }
    }

    // Fallback: Check the global catalog since populated app entities might be shallow
    final entityId = entity['_id']?.toString() ?? application['university']?['_id']?.toString() ?? application['scholarship']?['_id']?.toString();
    if (entityId != null && entityId.isNotEmpty) {
      final catalogUniversity = ApiService.allUniversities.firstWhere(
        (u) {
          final uMap = u is Map ? u : null;
          return uMap?['_id']?.toString() == entityId;
        },
        orElse: () => null,
      );
      if (catalogUniversity != null && catalogUniversity is Map) {
        final Map<String, dynamic> cMap = Map<String, dynamic>.from(catalogUniversity);
        final catalogValue = _pickFromMapByKeys(cMap, keys) ?? _pickFromMapByKeys(cMap['schedule'], keys);
        final formatted = _formatOptionalDate(catalogValue);
        if (formatted != null && formatted.trim().isNotEmpty) return catalogValue;
      }
      
      final catalogScholarship = ApiService.allScholarships.firstWhere(
        (s) {
          final sMap = s is Map ? s : null;
          return sMap?['_id']?.toString() == entityId;
        },
        orElse: () => null,
      );
      if (catalogScholarship != null && catalogScholarship is Map) {
        final Map<String, dynamic> cMap = Map<String, dynamic>.from(catalogScholarship);
        final catalogValue = _pickFromMapByKeys(cMap, keys) ?? _pickFromMapByKeys(cMap['schedule'], keys);
        final formatted = _formatOptionalDate(catalogValue);
        if (formatted != null && formatted.trim().isNotEmpty) return catalogValue;
      }
    }

    final offered = application['offeredUniversities'];
    if (offered is List) {
      for (final rawEntry in offered) {
        final entry = rawEntry is Map ? Map<String, dynamic>.from(rawEntry) : null;
        if (entry == null) continue;
        final fromEntry = _pickFromMapByKeys(entry, keys);
        final formatted = _formatOptionalDate(fromEntry);
        if (formatted != null && formatted.trim().isNotEmpty) {
          return fromEntry;
        }
      }
    }

    return null;
  }

  List<String> _normalizeSteps(dynamic rawSteps) {
    List<dynamic> stepsRaw = [];
    if (rawSteps is List) {
      stepsRaw = rawSteps;
    } else if (rawSteps is String) {
      final trimmed = rawSteps.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            stepsRaw = decoded;
          }
        } catch (_) {
          stepsRaw = trimmed.split(',');
        }
      }
    }

    final steps = stepsRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (steps.isEmpty) {
      steps.addAll(['Applied', 'Admit Card', 'Test', 'Interview']);
    }

    final hasApplied = steps.any(
      (step) => step.toLowerCase().trim() == 'applied',
    );
    if (!hasApplied) {
      steps.insert(0, 'Applied');
    }

    return steps;
  }

  String _scholarshipProgramSummary(
    Map<String, dynamic> application,
    Map<String, dynamic> entity,
  ) {
    final selectedPrograms = application['selectedPrograms'];
    if (selectedPrograms is List && selectedPrograms.isNotEmpty) {
      final names = selectedPrograms
          .map((item) {
            final map = item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{};
            return (map['programName'] ?? map['name'] ?? '')
                .toString()
                .trim();
          })
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) {
        if (names.length == 1) return names.first;
        return '${names.first} +${names.length - 1} more';
      }
    }

    final rawPrograms = entity['programs'];
    if (rawPrograms is List && rawPrograms.isNotEmpty) {
      final names = rawPrograms
          .whereType<Map>()
          .map(
            (item) =>
                (item['name'] ?? item['programName'] ?? '').toString().trim(),
          )
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) {
        if (names.length == 1) return names.first;
        return '${names.first} +${names.length - 1} more';
      }
    }

    return '';
  }

  Future<void> _refreshApp({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) {
      setState(() => _isRefreshing = true);
    }
    try {
      // Sync fresh data from server manually
      await ApiService.syncAllUserData();
      _updateFromLocalCache();
    } finally {
      if (mounted && showLoader) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _app['type'];
    final entity = type == 'University'
        ? _app['university']
        : _app['scholarship'];

    // Guard: if entity data is missing, show a safe fallback
    if (entity == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Application Detail'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading application data...',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshApp,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final name = type == 'University' ? entity['name'] : entity['title'];
    final status = _app['status'] ?? 'Applied';
    final List<String> steps = _normalizeSteps(entity['applicationSteps']);
    if (steps.isNotEmpty &&
        ![
          'result',
          'selected',
          'rejected',
        ].contains(steps.last.toLowerCase())) {
      steps.add('Selected');
    }

    final entityMap = entity is Map
        ? Map<String, dynamic>.from(entity)
        : <String, dynamic>{};
    final String? testDate = _formatOptionalDate(
      _pickScheduleValue(
        application: _app,
        entity: entityMap,
        isTest: true,
      ),
    );
    final String? interviewDate = _formatOptionalDate(
      _pickScheduleValue(
        application: _app,
        entity: entityMap,
        isTest: false,
      ),
    );
    final locationText = [
      entity['city']?.toString().trim(),
      entity['state']?.toString().trim(),
      entity['country']?.toString().trim(),
    ].where((part) => (part ?? '').isNotEmpty).join(', ');
    final scholarshipProgramSummary = _scholarshipProgramSummary(_app, entity);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Application Detail',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            fontSize: UiHelper.responsiveFontSize(context, 18),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
              color: const Color(0xFF2E8B57),
            ),
            onPressed: _refreshApp,
          ),
        ],
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshApp,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: UiHelper.responsivePadding(
            context,
            horizontal: 20,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(UiHelper.scale(context, 24)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: UiHelper.responsiveFontSize(context, 10),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2E8B57),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name ?? 'Unnamed',
                      style: TextStyle(
                        fontSize: UiHelper.responsiveFontSize(context, 22),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText.isNotEmpty
                                ? locationText
                                : 'Location not available',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: UiHelper.responsiveFontSize(
                                context,
                                14,
                              ),
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((entity['address']?.toString().trim().isNotEmpty ??
                        false)) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.home_work_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entity['address'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: UiHelper.responsiveFontSize(
                                  context,
                                  13,
                                ),
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (type == 'Scholarship' &&
                        scholarshipProgramSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              scholarshipProgramSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: UiHelper.responsiveFontSize(
                                  context,
                                  13,
                                ),
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'TRACKING STATUS',
                style: TextStyle(
                  fontSize: UiHelper.responsiveFontSize(context, 11),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),

              // Stepper
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: UiHelper.scale(context, 12),
                  vertical: UiHelper.scale(context, 24),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildStepper(
                  context,
                  steps,
                  status,
                  testDate,
                  interviewDate,
                ),
              ),

              if (testDate != null || interviewDate != null) ...[
                const SizedBox(height: 24),
                Text(
                  'SCHEDULE',
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 11),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                _buildScheduleCard(context, testDate, interviewDate),
              ],

              if (_hasFileValue(_app['admitCard']) ||
                  _hasFileValue(_app['offerLetter'])) ...[
                const SizedBox(height: 24),
                Text(
                  'DOWNLOADS',
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 11),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDownloadsSection(context, _app),
              ],

              if (type == 'Scholarship' &&
                  (_app['offeredUniversities'] as List?)?.isNotEmpty ==
                      true) ...[
                const SizedBox(height: 24),
                Text(
                  'UNIVERSITY ADMISSIONS',
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 11),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                ...(_app['offeredUniversities'] as List).map(
                  (uniData) => _buildOfferedUniTile(
                    context,
                    Map<String, dynamic>.from(uniData),
                  ),
                ),
              ],
              SizedBox(height: UiHelper.scale(context, 48)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferedUniTile(
    BuildContext context,
    Map<String, dynamic> uniData,
  ) {
    final uni = Map<String, dynamic>.from(uniData['university'] ?? {});
    final uStatus = uniData['status'] ?? 'Applied';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(UiHelper.scale(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (uni['thumbnail'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ApiService.getFullUrl(uni['thumbnail']),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    memCacheWidth: 120,
                    memCacheHeight: 120,
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFFF1F5F9)),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.business_rounded, size: 24),
                  ),
                )
              else
                const Icon(
                  Icons.business_rounded,
                  size: 40,
                  color: Color(0xFF2E8B57),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uni['name'] ?? 'University',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Admission Status: $uStatus',
                      style: TextStyle(
                        color: const Color(0xFF2E8B57),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // MINI STEPPER FOR EACH UNI
          _buildMiniStepper(
            context,
            _normalizeSteps(uni['applicationSteps']),
            uStatus,
          ),
          const SizedBox(height: 12),
          if (_hasFileValue(uniData['admitCard']) ||
              _hasFileValue(uniData['offerLetter'])) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              children: [
                if (_hasFileValue(uniData['admitCard']))
                  Expanded(
                    child: _miniDownloadButton(
                      context,
                      'Admit Card',
                      uniData['admitCard']?.toString(),
                      field: 'admitCard',
                      universityId: uni['_id']?.toString(),
                      universityName: uni['name']?.toString(),
                    ),
                  ),
                if (_hasFileValue(uniData['admitCard']) &&
                    _hasFileValue(uniData['offerLetter']))
                  const SizedBox(width: 8),
                if (_hasFileValue(uniData['offerLetter']))
                  Expanded(
                    child: _miniDownloadButton(
                      context,
                      'Offer Letter',
                      uniData['offerLetter']?.toString(),
                      field: 'offerLetter',
                      universityId: uni['_id']?.toString(),
                      universityName: uni['name']?.toString(),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniDownloadButton(
    BuildContext context,
    String title,
    String? fileName, {
    required String field,
    String? universityId,
    String? universityName,
  }) {
    return ElevatedButton.icon(
      onPressed: () async {
        if (fileName == null || fileName.isEmpty) return;
        await _downloadAndOpenApplicationDoc(
          field: field,
          sourceFile: fileName,
          universityId: universityId,
          universityName: universityName,
        );
      },
      icon: const Icon(Icons.download_rounded, size: 16),
      label: Text(
        title,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF1F5F9),
        foregroundColor: const Color(0xFF475569),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
    );
  }

  Widget _buildStepper(
    BuildContext context,
    List<dynamic> steps,
    String currentStatus,
    String? testDate,
    String? interviewDate,
  ) {
    int currentIndex = -1;
    final String currentStatusLower = currentStatus.toLowerCase();

    for (int i = 0; i < steps.length; i++) {
      if (steps[i].toString().toLowerCase() == currentStatusLower) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex == -1 && currentStatusLower == 'rejected') {
      currentIndex = steps.length - 1;
    }
    if (currentIndex == -1 && currentStatusLower == 'selected') {
      currentIndex = steps.length - 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          bool isCompleted =
              index < currentIndex ||
              (currentStatusLower == 'selected' && index == steps.length - 1);
          bool isCurrent = index == currentIndex;
          bool isRejected = currentStatusLower == 'rejected' && isCurrent;

          Color accentColor = const Color(0xFF2E8B57);
          if (isCurrent) accentColor = const Color(0xFF2E8B57);
          if (isCompleted) accentColor = const Color(0xFF10B981);
          if (isRejected) accentColor = const Color(0xFFEF4444);

          Color circleColor = (isCurrent || isCompleted)
              ? accentColor
              : const Color(0xFFE2E8F0);

          String displayDate = '';
          if (step.toString().toLowerCase().contains('test') &&
              testDate != null) {
            displayDate = testDate;
          }
          if (step.toString().toLowerCase().contains('interview') &&
              interviewDate != null) {
            displayDate = interviewDate;
          }

          String stepLabel = step.toString();
          // Force the last step to reflect the actual final state if defined
          if (index == steps.length - 1) {
            if (currentStatusLower == 'rejected') {
              stepLabel = 'Rejected';
            } else if (currentStatusLower == 'selected' ||
                stepLabel.toLowerCase() == 'selected' ||
                stepLabel.toLowerCase() == 'done') {
              stepLabel = 'Selected';
            }
          }

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: index == 0
                            ? Colors.transparent
                            : (index <= currentIndex
                                  ? (isRejected
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981))
                                  : const Color(0xFFF1F5F9)),
                      ),
                    ),
                    Container(
                      width: UiHelper.scale(context, 32),
                      height: UiHelper.scale(context, 32),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? accentColor
                            : (isCompleted
                                  ? accentColor.withValues(alpha: 0.1)
                                  : Colors.white),
                        shape: BoxShape.circle,
                        border: Border.all(color: circleColor, width: 2.5),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check_rounded,
                                size: UiHelper.scale(context, 18),
                                color: accentColor,
                              )
                            : (isCurrent
                                  ? (isRejected
                                        ? Icon(
                                            Icons.close_rounded,
                                            size: UiHelper.scale(context, 18),
                                            color: Colors.white,
                                          )
                                        : Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ))
                                  : Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: circleColor,
                                        shape: BoxShape.circle,
                                      ),
                                    )),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2.5,
                        color: index == steps.length - 1
                            ? Colors.transparent
                            : (index < currentIndex
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF1F5F9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stepLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: UiHelper.responsiveFontSize(context, 9.5),
                    fontWeight: (isCurrent || isCompleted)
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isRejected
                        ? const Color(0xFFEF4444)
                        : ((isCurrent || isCompleted)
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8)),
                    height: 1.1,
                  ),
                ),
                if (displayDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      displayDate,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: UiHelper.responsiveFontSize(context, 8),
                        color: isCurrent
                            ? accentColor
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDownloadsSection(
    BuildContext context,
    Map<String, dynamic> app,
  ) {
    final List<Widget> children = [];

    // Application-specific documents only.
    if (_hasFileValue(app['admitCard'])) {
      children.add(
        _downloadTile(
          context,
          'Admit Card',
          app['admitCard']?.toString(),
          field: 'admitCard',
        ),
      );
    }
    if (_hasFileValue(app['offerLetter'])) {
      children.add(
        _downloadTile(
          context,
          'Offer Letter',
          app['offerLetter']?.toString(),
          field: 'offerLetter',
        ),
      );
    }

    if (children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No documents available for download.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return Column(children: children);
  }

  Widget _buildScheduleCard(
    BuildContext context,
    String? testDate,
    String? interviewDate,
  ) {
    return Container(
      padding: EdgeInsets.all(UiHelper.scale(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          if (testDate != null)
            _buildScheduleRow(
              context,
              Icons.quiz_rounded,
              'Test Date',
              testDate,
              const Color(0xFF2E8B57),
            ),
          if (testDate != null && interviewDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: const Color(0xFFE2E8F0)),
            ),
          if (interviewDate != null)
            _buildScheduleRow(
              context,
              Icons.record_voice_over_rounded,
              'Interview Date',
              interviewDate,
              const Color(0xFF2E8B57),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(
    BuildContext context,
    IconData icon,
    String label,
    String date,
    Color accent,
  ) {
    return Row(
      children: [
        Container(
          width: UiHelper.scale(context, 36),
          height: UiHelper.scale(context, 36),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: UiHelper.scale(context, 18)),
        ),
        SizedBox(width: UiHelper.scale(context, 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: UiHelper.responsiveFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: UiHelper.responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStepper(
    BuildContext context,
    List<dynamic> steps,
    String currentStatus,
  ) {
    int currentIndex = -1;
    final String currentStatusLower = currentStatus.toLowerCase();

    // Auto-fix steps if they don't have Result/Selected tail
    final List<dynamic> displaySteps = List.from(steps);
    if (displaySteps.isNotEmpty &&
        ![
          'result',
          'selected',
          'rejected',
        ].contains(displaySteps.last.toString().toLowerCase())) {
      displaySteps.add('Selected');
    }

    for (int i = 0; i < displaySteps.length; i++) {
      if (displaySteps[i].toString().toLowerCase() == currentStatusLower) {
        currentIndex = i;
        break;
      }
    }
    if (currentIndex == -1 && currentStatusLower == 'rejected') {
      currentIndex = displaySteps.length - 1;
    }
    if (currentIndex == -1 && currentStatusLower == 'selected') {
      currentIndex = displaySteps.length - 1;
    }

    return Row(
      children: List.generate(displaySteps.length, (index) {
        final isCompleted =
            index < currentIndex ||
            (currentStatusLower == 'selected' &&
                index == displaySteps.length - 1);
        final isCurrent = index == currentIndex;
        final isRejected = currentStatusLower == 'rejected' && isCurrent;

        Color color = isCurrent
            ? const Color(0xFF2E8B57)
            : (isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0));
        if (isRejected) color = const Color(0xFFEF4444);

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index == 0
                          ? Colors.transparent
                          : (index <= currentIndex
                                ? color
                                : const Color(0xFFF1F5F9)),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index == displaySteps.length - 1
                          ? Colors.transparent
                          : (index < currentIndex
                                ? color
                                : const Color(0xFFF1F5F9)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                displaySteps[index].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _downloadTile(
    BuildContext context,
    String title,
    String? fileName, {
    String? field,
    String? universityId,
    String? universityName,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () async {
          if (fileName == null || fileName.isEmpty) {
            UiHelper.showCustomSnackBar(
              context,
              'Document missing.',
              isError: true,
            );
            return;
          }

          if (field == 'admitCard' || field == 'offerLetter') {
            await _downloadAndOpenApplicationDoc(
              field: field!,
              sourceFile: fileName,
              universityId: universityId,
              universityName: universityName,
            );
            return;
          }

          final url = ApiService.getUploadUrl(fileName);
          final uri = Uri.parse(url);
          final success = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!success && context.mounted) {
            UiHelper.showCustomSnackBar(
              context,
              'Could not open document.',
              isError: true,
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(UiHelper.scale(context, 16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFEF4444),
                  size: UiHelper.scale(context, 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: UiHelper.responsiveFontSize(context, 15),
                  ),
                ),
              ),
              Icon(
                Icons.download_for_offline_rounded,
                color: const Color(0xFF2E8B57),
                size: UiHelper.scale(context, 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
