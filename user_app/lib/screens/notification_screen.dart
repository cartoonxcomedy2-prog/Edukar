import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';
import './application_detail_screen.dart';
import './scholarship_detail_screen.dart';
import './university_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isFetching = false;
  List<dynamic> _notifications = [];
  String? _lastNotificationsHash;
  String? _errorMessage;
  StreamSubscription? _updateSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      _syncFromCache();
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (!mounted || _isFetching) return;
    _isFetching = true;
    if (!silent && _notifications.isEmpty) setState(() => _isLoading = true);

    try {
      final notifications = await ApiService.fetchNotifications(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final hash = ApiService.listFingerprint(notifications);
      final hasUnread = notifications.any((raw) {
        final item = _asMap(raw);
        return item != null && item['isRead'] != true;
      });
      if (hasUnread && !silent) {
        ApiService.markAllNotificationsAsRead();
      }
      if (hash == _lastNotificationsHash && _notifications.isNotEmpty) {
        if (_isLoading) setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _notifications = notifications;
        _lastNotificationsHash = hash;
        _errorMessage = null;
        _isLoading = false;
      });
      if (notifications.isNotEmpty) {
        _syncFromCache();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  void _syncFromCache() {
    if (!mounted) return;
    final local = ApiService.currentUser?['notifications'] as List? ?? [];
    final hash = ApiService.listFingerprint(local);
    if (hash == _lastNotificationsHash) return;

    setState(() {
      _notifications = List<dynamic>.from(local);
      _lastNotificationsHash = hash;
      _isLoading = false;
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        final hours = diff.inHours % 24;
        if (hours > 0) return '${diff.inDays}d ${hours}h';
        final mins = diff.inMinutes % 60;
        if (mins > 0) return '${diff.inDays}d ${mins}m';
        return '${diff.inDays}d';
      }
      if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        if (mins > 0) return '${diff.inHours}h ${mins}m';
        return '${diff.inHours}h';
      }
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return '';
    }
  }

  String _normalizeComparable(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '');
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _findApplicationForNotification(
    Map<String, dynamic> notification,
    Map<String, dynamic> data,
  ) {
    final apps = ApiService.currentUser?['applications'] as List? ?? [];
    if (apps.isEmpty) return null;

    final applicationId =
        data['applicationId']?.toString() ??
        notification['applicationId']?.toString();
    final entityId = data['entityId']?.toString();

    for (final raw in apps) {
      final app = _asMap(raw);
      if (app == null) continue;
      if (applicationId != null &&
          applicationId.isNotEmpty &&
          app['_id']?.toString() == applicationId) {
        return app;
      }
      if (entityId != null && entityId.isNotEmpty) {
        final university = _asMap(app['university']);
        final scholarship = _asMap(app['scholarship']);
        if (university?['_id']?.toString() == entityId ||
            scholarship?['_id']?.toString() == entityId) {
          return app;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _findOfferedUniversityForNotification({
    required Map<String, dynamic> application,
    required Map<String, dynamic> data,
    required Map<String, dynamic> notification,
  }) {
    final offeredList = application['offeredUniversities'];
    if (offeredList is! List || offeredList.isEmpty) return null;

    final targetUniversityId =
        data['universityId']?.toString().trim() ??
        data['entityId']?.toString().trim() ??
        notification['entityId']?.toString().trim() ??
        '';
    if (targetUniversityId.isEmpty) return null;

    for (final raw in offeredList) {
      final offered = _asMap(raw);
      if (offered == null) continue;
      final uni = _asMap(offered['university']);
      final uniId =
          uni?['_id']?.toString().trim() ??
          offered['university']?.toString().trim() ??
          '';
      if (uniId == targetUniversityId) {
        return uni ?? offered;
      }
    }
    return null;
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('admit card')) {
      return const Color(0xFF7C3AED);
    }
    if (normalized.contains('offer letter')) {
      return const Color(0xFF0F766E);
    }
    if (normalized.contains('applied')) {
      return const Color(0xFF0EA5E9);
    }
    if (normalized.contains('selected') ||
        normalized.contains('approved') ||
        normalized.contains('accepted')) {
      return const Color(0xFF10B981);
    }
    if (normalized.contains('rejected') || normalized.contains('declined')) {
      return const Color(0xFFEF4444);
    }
    if (normalized.contains('interview') || normalized.contains('test')) {
      return const Color(0xFFF59E0B);
    }
    if (normalized.contains('closing') || normalized.contains('deadline')) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            fontSize: UiHelper.responsiveFontSize(context, 18),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2E8B57)),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: const Color(0xFF2E8B57),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_errorMessage != null && _notifications.isEmpty)
            ? _buildErrorState()
            : _notifications.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                key: const PageStorageKey<String>('notifications_scroll_list'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                // Cards are compact rows — no fixed itemExtent needed.
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  if (item is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }
                  return RepaintBoundary(child: _buildNotificationCard(item));
                },
              ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final rawTitle = notification['title']?.toString() ?? 'Update';
    final rawBody = notification['body']?.toString() ?? '';
    final createdAt = _formatTime(notification['createdAt']?.toString());

    final data = _asMap(notification['data']) ?? <String, dynamic>{};
    final app = _findApplicationForNotification(notification, data);
    final appUniversity = _asMap(app?['university']);
    final appScholarship = _asMap(app?['scholarship']);
    final appOfferedUniversity = app == null
        ? null
        : _findOfferedUniversityForNotification(
            application: app,
            data: data,
            notification: notification,
          );

    String pickFirst(List<dynamic> values) {
      for (final raw in values) {
        final value = raw?.toString() ?? '';
        if (value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    String pickFirstExcluding(
      List<dynamic> values,
      Set<String> excludedNormalized,
    ) {
      for (final raw in values) {
        final value = raw?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        final normalized = value.toLowerCase();
        if (excludedNormalized.contains(normalized)) continue;
        return value;
      }
      return '';
    }

    final universityName = pickFirst([
      data['universityName'],
      appOfferedUniversity?['name'],
      appUniversity?['name'],
      (data['entityType']?.toString().toLowerCase() == 'university')
          ? data['entityName']
          : null,
    ]);

    final scholarshipName = pickFirst([
      data['scholarshipName'],
      appScholarship?['title'],
      (data['entityType']?.toString().toLowerCase() == 'scholarship')
          ? data['entityName']
          : null,
    ]);

    final entityName = pickFirst([
      data['entityName'],
      notification['entityName'],
      scholarshipName,
      universityName,
      'Opportunity',
    ]);

    final status =
        data['status']?.toString() ?? notification['status']?.toString() ?? '';

    final entityType =
        data['entityType']?.toString() ??
        notification['entityType']?.toString();

    final lowerEntityType = (entityType ?? '').toLowerCase();
    final scholarshipThumbs = <String>{
      (data['scholarshipThumbnail']?.toString() ?? '').trim().toLowerCase(),
      (appScholarship?['thumbnail']?.toString() ?? '').trim().toLowerCase(),
      (appScholarship?['image']?.toString() ?? '').trim().toLowerCase(),
    }..removeWhere((value) => value.isEmpty);
    final entityThumbnail = lowerEntityType == 'university'
        ? pickFirstExcluding([
            appOfferedUniversity?['thumbnail'],
            appOfferedUniversity?['logo'],
            data['universityThumbnail'],
            appUniversity?['thumbnail'],
            appUniversity?['logo'],
            data['entityThumbnail'],
            notification['entityThumbnail'],
          ], scholarshipThumbs)
        : lowerEntityType == 'scholarship'
        ? pickFirst([
            data['scholarshipThumbnail'],
            appScholarship?['thumbnail'],
            appScholarship?['image'],
            data['entityThumbnail'],
            notification['entityThumbnail'],
          ])
        : pickFirst([
            data['entityThumbnail'],
            notification['entityThumbnail'],
            data['universityThumbnail'],
            appOfferedUniversity?['thumbnail'],
            appOfferedUniversity?['logo'],
            appUniversity?['thumbnail'],
            appUniversity?['logo'],
            data['scholarshipThumbnail'],
            appScholarship?['thumbnail'],
            appScholarship?['image'],
          ]);

    final primaryEntityName = lowerEntityType == 'university'
        ? (universityName.isNotEmpty ? universityName : entityName)
        : lowerEntityType == 'scholarship'
        ? (scholarshipName.isNotEmpty ? scholarshipName : entityName)
        : entityName;
    final normalizedPrimary = _normalizeComparable(primaryEntityName);
    final normalizedUniversity = _normalizeComparable(universityName);
    final normalizedScholarship = _normalizeComparable(scholarshipName);
    final sameUniversityScholarship =
        normalizedUniversity.isNotEmpty &&
        normalizedUniversity == normalizedScholarship;
    final showUniversityTag =
        universityName.isNotEmpty &&
        lowerEntityType != 'university' &&
        normalizedUniversity != normalizedPrimary &&
        !sameUniversityScholarship;
    final showScholarshipTag =
        scholarshipName.isNotEmpty &&
        lowerEntityType != 'scholarship' &&
        normalizedScholarship != normalizedPrimary;

    String title = rawTitle.trim();
    final entityPrefixVariants = <String>[
      '$primaryEntityName - ',
      '$primaryEntityName: ',
      '$entityName - ',
      '$entityName: ',
    ]..removeWhere((v) => v.trim().isEmpty);

    for (final prefix in entityPrefixVariants) {
      if (title.toLowerCase().startsWith(prefix.toLowerCase())) {
        title = title.substring(prefix.length).trim();
        break;
      }
    }
    if (title.isEmpty) title = 'Update';

    String body = rawBody.trim();
    final lowerBody = body.toLowerCase();
    final lowerStatus = status.toLowerCase();
    if (status.isNotEmpty &&
        lowerBody.contains('status') &&
        lowerBody.contains(lowerStatus)) {
      body = '';
    }

    final accent = isRead ? const Color(0xFFE2E8F0) : const Color(0xFF2E8B57);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF1FBF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDCC8),
        ),
        boxShadow: isRead ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          _handleNotificationClick(notification);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: entityThumbnail.isNotEmpty
                      ? UiHelper.buildImage(
                          ApiService.getFullUrl(entityThumbnail),
                          fit: BoxFit.cover,
                          width: 52,
                          height: 52,
                          cacheWidth: UiHelper.cacheSizePx(context, 52),
                          cacheHeight: UiHelper.cacheSizePx(context, 52),
                          errorWidget: _defaultIcon(entityType),
                        )
                      : _defaultIcon(entityType),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            primaryEntityName.isEmpty ? title : primaryEntityName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                              height: 1.15,
                            ),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFEF4444),
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        else
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            primaryEntityName.isEmpty ? body : title,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ((entityType?.isEmpty ?? true) ? 'Alert' : entityType!).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (body.isNotEmpty && primaryEntityName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (status.isNotEmpty || showUniversityTag || showScholarshipTag) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (status.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _statusColor(status),
                                ),
                              ),
                            ),
                          if (showUniversityTag)
                            _buildEntityMetaTag(
                              icon: Icons.account_balance_rounded,
                              label: 'Uni',
                              value: universityName,
                            ),
                          if (showScholarshipTag)
                            _buildEntityMetaTag(
                              icon: Icons.school_rounded,
                              label: 'Sch',
                              value: scholarshipName,
                            ),
                        ],
                      ),
                    ],
                    if (!isRead) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntityMetaTag({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultIcon(String? type) {
    return Icon(
      type?.toLowerCase() == 'university'
          ? Icons.business_rounded
          : Icons.school_rounded,
      color: const Color(0xFFCBD5E1),
      size: 20,
    );
  }

  Future<void> _handleNotificationClick(
    Map<String, dynamic> notification,
  ) async {
    final data = (notification['data'] is Map<String, dynamic>)
        ? notification['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final notifType = data['type']?.toString();
    final entityId = data['entityId']?.toString();
    final entityType = data['entityType']?.toString().toLowerCase();

    if (notifType == 'deadline-reminder' &&
        entityId != null &&
        entityType != null) {
      if (entityType == 'university') {
        var university = ApiService.allUniversities.firstWhere(
          (u) => u['_id']?.toString() == entityId,
          orElse: () => null,
        );
        if (university == null) {
          final list = await ApiService.fetchUniversities(forceRefresh: false);
          university = list.firstWhere(
            (u) => u['_id']?.toString() == entityId,
            orElse: () => null,
          );
        }
        if (university != null) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UniversityDetailScreen(university: university),
            ),
          );
        }
      } else if (entityType == 'scholarship') {
        var scholarship = ApiService.allScholarships.firstWhere(
          (s) => s['_id']?.toString() == entityId,
          orElse: () => null,
        );
        if (scholarship == null) {
          final list = await ApiService.fetchScholarships(forceRefresh: false);
          scholarship = list.firstWhere(
            (s) => s['_id']?.toString() == entityId,
            orElse: () => null,
          );
        }
        if (scholarship != null) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScholarshipDetailScreen(scholarship: scholarship),
            ),
          );
        }
      }
      return;
    }

    final applicationId = data['applicationId']?.toString();

    if (data['type'] != 'application' ||
        (applicationId == null && entityId == null)) {
      return;
    }

    final apps = ApiService.currentUser?['applications'] as List? ?? [];
    final app = apps.firstWhere((a) {
      if (applicationId != null && a['_id']?.toString() == applicationId) {
        return true;
      }
      final entity = a['type'] == 'University'
          ? a['university']
          : a['scholarship'];
      return entityId != null && entity?['_id']?.toString() == entityId;
    }, orElse: () => null);

    if (app != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApplicationDetailScreen(application: app),
        ),
      );
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey[350]),
            const SizedBox(height: 12),
            const Text(
              'Network issue',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your internet and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 50,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          const Text(
            'No updates yet',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
