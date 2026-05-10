import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';
import './university_detail_screen.dart';

class UniversityScreen extends StatefulWidget {
  const UniversityScreen({super.key});

  @override
  State<UniversityScreen> createState() => _UniversityScreenState();
}

class _UniversityScreenState extends State<UniversityScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _bg = Color(0xFFF8FAF9);
  static const Color _primary = Color(0xFF2E8B57);

  @override
  bool get wantKeepAlive => true;

  bool _searchExpanded = false;
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  List<dynamic> _universities = [];
  List<dynamic> _filteredCache = [];
  Map<String, dynamic> _applicationByUniId = {};
  bool _loading = true;
  Timer? _debounce;
  StreamSubscription? _updateSubscription;
  String? _lastDataHash;

  @override
  void initState() {
    super.initState();
    _initFetch();
    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      if (mounted) _loadFromCache();
    });
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _debounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initFetch() async {
    await _loadFromCache();
    _fetchData();
  }

  Future<void> _loadFromCache() async {
    final cached = await ApiService.fetchUniversities(forceRefresh: false);
    if (mounted) _syncState(cached);
  }

  Future<void> _fetchData() async {
    try {
      final fresh = await ApiService.fetchUniversities(forceRefresh: true);
      if (mounted) _syncState(fresh);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncState(List<dynamic> data) {
    final newHash = ApiService.listFingerprint(data);
    final appHash = ApiService.currentUser?['applications']?.length?.toString() ?? '0';
    final combinedHash = '$newHash-$appHash';
    if (combinedHash == _lastDataHash && !_loading) return;
    _lastDataHash = combinedHash;

    setState(() {
      _universities = data;
      _applicationByUniId = _buildApplicationIndex();
      _updateFilteredCache();
      _loading = false;
    });
  }

  Map<String, dynamic> _buildApplicationIndex() {
    final indexed = <String, dynamic>{};
    final apps = ApiService.currentUser?['applications'];
    if (apps is List) {
      for (var app in apps) {
        final uniId = app['university']?['_id']?.toString();
        if (uniId != null) indexed[uniId] = app;
      }
    }
    return indexed;
  }

  void _updateFilteredCache() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredCache = List.from(_universities);
      return;
    }
    _filteredCache = _universities.where((u) {
      final name = u['name']?.toString().toLowerCase() ?? '';
      final city = u['city']?.toString().toLowerCase() ?? '';
      return name.contains(q) || city.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: _searchExpanded
            ? _buildSearchField()
            : const Text('Universities', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10231A))),
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close : Icons.search, color: _primary),
            onPressed: () {
              setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) {
                  _searchController.clear();
                  _searchQuery = '';
                  _updateFilteredCache();
                }
              });
              if (_searchExpanded) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
              }
            },
          ),
        ],
      ),
      body: _loading && _universities.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: _fetchData,
        color: _primary,
        child: _filteredCache.isEmpty
            ? const Center(child: Text("No Universities Found"))
            : ListView.builder(
          // CACHE EXTENT: Extra padding for images so they load before scrolling into view
          cacheExtent: 2000,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: _filteredCache.length,
          itemBuilder: (context, index) {
            final uni = _filteredCache[index];
            return UniversityCard(
              key: ValueKey(uni['_id'] ?? index),
              uni: uni,
              screenWidth: screenWidth,
              application: _applicationByUniId[uni['_id']?.toString()],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocus,
      decoration: const InputDecoration(hintText: 'Search universities...', border: InputBorder.none),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _searchQuery = v;
              _updateFilteredCache();
            });
          }
        });
      },
    );
  }
}

class UniversityCard extends StatelessWidget {
  final Map<String, dynamic> uni;
  final Map<String, dynamic>? application;
  final double screenWidth;
  static final _df = DateFormat('dd MMM, yyyy');

  const UniversityCard({super.key, required this.uni, required this.application, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final bool isApplied = application != null;
    final String deadlineStr = _getDeadline();
    final bool isClosed = _isDeadlinePassed() || !(uni['isActive'] ?? true);
    final String type = (uni['universityType'] ?? uni['type'] ?? 'N/A').toString().toUpperCase();
    final String fee = (uni['applicationFee'] ?? uni['applicationFees'] ?? '0').toString();

    return RepaintBoundary( // Prevent full list rebuild on scroll
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => UniversityDetailScreen(university: uni)));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    // OPTIMIZED IMAGE RENDERING
                    UiHelper.buildImage(
                      ApiService.getUploadUrl(uni['thumbnail'] ?? uni['logo']),
                      height: 180,
                      width: screenWidth,
                      fit: BoxFit.cover,
                      // Note: Check if your UiHelper support memCache / cacheWidth
                      // Ideally you'd pass: cacheWidth: (screenWidth * MediaQuery.of(context).devicePixelRatio).toInt()
                    ),
                    Positioned(top: 12, left: 12, child: _badge(isClosed, isApplied, application?['status'])),

                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uni['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF10231A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${uni['city'] ?? ''}, ${uni['country'] ?? ''}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 25, color: Color(0xFFF5F5F5)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _info(Icons.account_balance_wallet_outlined, "APPLICATION FEE", "Rs $fee", const Color(0xFF2E8B57)),
                          _info(Icons.calendar_today_outlined, "DEADLINE", deadlineStr, isClosed ? Colors.red : Colors.black87),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _badge(bool isClosed, bool isApplied, String? apiStatus) {
    String label = "APPLY NOW"; Color color = const Color(0xFFF97316);
    final status = apiStatus?.toLowerCase().trim();
    if (status == 'selected') { label = "SELECTED"; color = Colors.green; }
    else if (status == 'rejected') { label = "REJECTED"; color = Colors.red; }
    else if (isClosed) { label = "CLOSED"; color = Colors.red; }
    else if (isApplied) { label = "APPLIED"; color = const Color(0xFF64748B); }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  String _getDeadline() {
    final d = uni['deadline'] ?? uni['lastDate'];
    if (d == null) return 'N/A';
    try { return _df.format(DateTime.parse(d.toString())); }
    catch (_) { return d.toString(); }
  }

  bool _isDeadlinePassed() {
    final d = uni['deadline'] ?? uni['lastDate'];
    if (d == null) return false;
    final parsed = DateTime.tryParse(d.toString());
    return parsed != null && parsed.isBefore(DateTime.now());
  }
}