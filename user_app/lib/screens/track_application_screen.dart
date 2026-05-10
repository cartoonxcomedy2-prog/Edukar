import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import './application_detail_screen.dart';

class TrackApplicationScreen extends StatefulWidget {
  const TrackApplicationScreen({super.key});

  @override
  State<TrackApplicationScreen> createState() => _TrackApplicationScreenState();
}

class _TrackApplicationScreenState extends State<TrackApplicationScreen> {
  bool _isLoading = true;
  List<dynamic> _allApplications = [];
  List<dynamic> _filteredApplications = [];
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _updateSubscription;
  Timer? _searchDebounce;

  void _showKeyboardNow() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  void initState() {
    super.initState();
    _loadApplications();

    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      if (mounted) _refreshFromLocal();
    });
  }

  void _refreshFromLocal() {
    if (!mounted) return;
    final latest = _excludeReapplyEligible(
      ApiService.currentUser?['applications'] as List? ?? const [],
    );
    final filtered = _filterApplications(_searchController.text, latest);
    setState(() {
      _allApplications = latest;
      _filteredApplications = filtered;
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    if (!mounted) return;

    final existing = _excludeReapplyEligible(
      ApiService.currentUser?['applications'] as List? ?? const [],
    );
    if (existing.isNotEmpty) {
      final filtered = _filterApplications(_searchController.text, existing);
      setState(() {
        _allApplications = existing;
        _filteredApplications = filtered;
        _isLoading = false;
      });
    }

    try {
      await ApiService.syncAllUserData();
      if (mounted) {
        final latest = _excludeReapplyEligible(
          ApiService.currentUser?['applications'] as List? ?? const [],
        );
        final filtered = _filterApplications(_searchController.text, latest);
        setState(() {
          _allApplications = latest;
          _filteredApplications = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _excludeReapplyEligible(List<dynamic> source) {
    return source.where((raw) {
      if (raw is! Map) return true;
      final flag = raw['isReapplyEligible'];
      if (flag == true) return false;
      return flag?.toString().toLowerCase() != 'true';
    }).toList();
  }

  List<dynamic> _filterApplications(String query, List<dynamic> source) {
    final normalized = query.trim();
    if (normalized.isEmpty || normalized.length < 2) {
      return List<dynamic>.from(source);
    }

    final lowerQuery = normalized.toLowerCase();
    return source.where((app) {
      if (app is! Map<String, dynamic>) return false;
      final title = _entityTitle(app).toLowerCase();
      final institution = _institutionTitle(app).toLowerCase();
      final status = (app['status']?.toString() ?? '').toLowerCase();
      return title.contains(lowerQuery) ||
          institution.contains(lowerQuery) ||
          status.contains(lowerQuery);
    }).toList();
  }

  void _runFilter(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      final results = _filterApplications(query, _allApplications);
      setState(() => _filteredApplications = results);
    });
  }

  String _entityTitle(Map<String, dynamic> app) {
    final type = app['type']?.toString().toLowerCase() ?? '';
    final entity = type == 'university'
        ? app['university']
        : app['scholarship'];
    if (entity is! Map) return 'Application';

    if (type == 'university') {
      return entity['name']?.toString().trim().isNotEmpty == true
          ? entity['name'].toString().trim()
          : 'Unnamed University';
    }

    return entity['title']?.toString().trim().isNotEmpty == true
        ? entity['title'].toString().trim()
        : 'Unnamed Scholarship';
  }

  String _institutionTitle(Map<String, dynamic> app) {
    final type = app['type']?.toString().toLowerCase() ?? '';
    final entity = type == 'university'
        ? app['university']
        : app['scholarship'];
    if (entity is! Map) return '';

    if (type == 'scholarship') {
      final uniName =
          entity['university_name']?.toString() ??
          entity['universityName']?.toString() ??
          '';
      return uniName.trim();
    }

    final city = entity['city']?.toString() ?? '';
    final country = entity['country']?.toString() ?? '';
    final location = [
      city,
      country,
    ].where((v) => v.trim().isNotEmpty).join(', ').trim();
    return location;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Color(0xFF0F172A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Track Status',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2E8B57)),
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _isLoading = true);
                _loadApplications();
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  onTap: _showKeyboardNow,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                  onChanged: _runFilter,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search applications...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),

                    // --- CANCEL BUTTON LOGIC ---
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _searchController.clear();
                            _runFilter('');
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                        );
                      },
                    ),

                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _isLoading && _allApplications.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E8B57)),
              )
            : RefreshIndicator(
                onRefresh: _loadApplications,
                color: const Color(0xFF2E8B57),
                child: _filteredApplications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        key: const PageStorageKey<String>(
                          'track_applications_scroll_list',
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _filteredApplications.length,
                        itemExtent: 200,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, index) {
                          return _TrackCard(
                            key: ValueKey(
                              _filteredApplications[index]['_id'] ??
                                  index.toString(),
                            ),
                            app: _filteredApplications[index],
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? 'No applications yet'
                    : 'No matching results',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try a different keyword or refresh',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  final Map<String, dynamic> app;
  const _TrackCard({required this.app, super.key});

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _entityTitle(String type, Map<String, dynamic>? entity) {
    if (entity == null) return 'Application';
    if (type == 'University') {
      final name = entity['name']?.toString().trim() ?? '';
      return name.isEmpty ? 'Unnamed University' : name;
    }
    final title = entity['title']?.toString().trim() ?? '';
    return title.isEmpty ? 'Unnamed Scholarship' : title;
  }

  String _institutionTitle(String type, Map<String, dynamic>? entity) {
    if (entity == null) return '';
    if (type == 'Scholarship') {
      final uniName =
          entity['university_name']?.toString() ??
          entity['universityName']?.toString() ??
          '';
      return uniName.trim();
    }
    final city = entity['city']?.toString() ?? '';
    final country = entity['country']?.toString() ?? '';
    return [city, country].where((v) => v.trim().isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final String type = app['type'] ?? 'University';
    final entity = _asMap(
      type == 'University' ? app['university'] : app['scholarship'],
    );

    if (entity == null) return const SizedBox.shrink();

    final String name = _entityTitle(type, entity);
    final String institution = _institutionTitle(type, entity);

    final String status = app['status'] ?? 'Applied';
    final statusLower = status.toLowerCase();

    // --- STATUS LOGIC ---
    Color statusColor = const Color(0xFF2E8B57); // Default (Applied)
    IconData statusIcon = Icons.hourglass_top_rounded; // Default Icon

    if (statusLower.contains('selected') ||
        statusLower.contains('approved') ||
        statusLower.contains('accepted')) {
      statusColor = const Color(0xFF10B981); // Green
      statusIcon = Icons.check_circle_rounded;
    } else if (statusLower.contains('rejected') ||
        statusLower.contains('declined')) {
      statusColor = const Color(0xFFEF4444); // Red
      statusIcon = Icons.cancel_rounded;
    } else if (statusLower.contains('applied') ||
        statusLower.contains('track') ||
        statusLower.contains('pending') ||
        statusLower.contains('under review')) {
      statusColor = const Color(0xFFF97316); // Orange for Track/Applied/Pending
      statusIcon = Icons.hourglass_top_rounded;
    } else if (statusLower.contains('closed') ||
        statusLower.contains('expired')) {
      statusColor = const Color(0xFF64748B); // Gray for Closed
      statusIcon = Icons.event_busy_rounded;
    } else if (statusLower.contains('interview') ||
        statusLower.contains('test')) {
      statusColor = const Color(0xFF2E8B57); // Green for Interview
      statusIcon = Icons.event_available_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApplicationDetailScreen(application: app),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _buildThumbnail(
                      entity['thumbnail'] ?? entity['image'],
                      type,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2E8B57),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (institution.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            institution,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // --- CLEAN STATUS ROW (NO BACKGROUND) ---
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              status.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // VIEW DETAILS BUTTON
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Text(
                          'Details',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                      ],
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

  Widget _buildThumbnail(String? thumb, String type) {
    if (thumb == null || thumb.isEmpty) {
      return Icon(
        type == 'University'
            ? Icons.school_rounded
            : Icons.workspace_premium_rounded,
        color: const Color(0xFF94A3B8),
        size: 24,
      );
    }

    if (thumb.startsWith('data:image')) {
      try {
        final parts = thumb.split(',');
        if (parts.length > 1) {
          return Image.memory(
            base64Decode(parts.last),
            fit: BoxFit.cover,
            cacheWidth: 150,
            gaplessPlayback: true,
          );
        }
      } catch (e) {
        return const Icon(Icons.broken_image_rounded, color: Color(0xFFCBD5E1));
      }
    }

    return CachedNetworkImage(
      imageUrl: ApiService.getFullUrl(thumb),
      fit: BoxFit.cover,
      memCacheWidth: 150,
      memCacheHeight: 150,
      placeholder: (context, url) => Container(color: const Color(0xFFF1F5F9)),
      errorWidget: (context, url, error) =>
          const Icon(Icons.broken_image_rounded, color: Color(0xFFCBD5E1)),
    );
  }
}
