import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';
import './scholarship_detail_screen.dart';

class ScholarshipScreen extends StatefulWidget {
  const ScholarshipScreen({super.key});

  @override
  State<ScholarshipScreen> createState() => _ScholarshipScreenState();
}

class _ScholarshipScreenState extends State<ScholarshipScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _bg = Color(0xFFF8FAF9);
  static const Color _primary = Color(0xFF2E8B57);

  bool _searchExpanded = false;
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  List<dynamic> _scholarships = [];
  List<dynamic> _filteredCache = [];
  Map<String, Map<String, dynamic>> _applicationByScholarshipId = {};
  bool _loading = true;
  Timer? _debounce;
  StreamSubscription? _updateSubscription;
  String? _lastDataHash;
  String _lastApplicationsHash = '';

  @override
  bool get wantKeepAlive => true;

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
    final cached = await ApiService.fetchScholarships(forceRefresh: false);
    if (mounted) _applyData(cached);
  }

  Future<void> _fetchData() async {
    try {
      final fresh = await ApiService.fetchScholarships(forceRefresh: true);
      if (mounted) _applyData(fresh);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyData(List<dynamic> data) {
    final newHash = ApiService.listFingerprint(data);
    final appHash = _currentApplicationsHash();
    if (newHash == _lastDataHash && appHash == _lastApplicationsHash && !_loading) return;

    setState(() {
      _lastDataHash = newHash;
      _lastApplicationsHash = appHash;
      _scholarships = data;
      _applicationByScholarshipId = _buildApplicationIndex();
      _updateFilteredCache();
      _loading = false;
    });
  }

  String _currentApplicationsHash() {
    final applications = ApiService.currentUser?['applications'];
    if (applications is! List) return 'none';
    return ApiService.listFingerprint(List<dynamic>.from(applications));
  }

  Map<String, Map<String, dynamic>> _buildApplicationIndex() {
    final indexed = <String, Map<String, dynamic>>{};
    final applications = ApiService.currentUser?['applications'];
    if (applications is! List) return indexed;
    for (final raw in applications) {
      if (raw is! Map) continue;
      final scholarship = raw['scholarship'];
      if (scholarship is! Map) continue;
      indexed[scholarship['_id']?.toString() ?? ''] = Map<String, dynamic>.from(raw);
    }
    return indexed;
  }

  void _updateFilteredCache() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredCache = List.from(_scholarships);
      return;
    }
    _filteredCache = _scholarships.where((s) {
      final title = s['title']?.toString().toLowerCase() ?? '';
      final uni = s['university_name']?.toString().toLowerCase() ?? '';
      return title.contains(q) || uni.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: _searchExpanded
            ? TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: true,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              setState(() { _searchQuery = v; _updateFilteredCache(); });
            });
          },
          decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none),
        )
            : const Text('Scholarships', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10231A))),
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close : Icons.search, color: _primary),
            onPressed: () {
              setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) {
                  _searchQuery = '';
                  _searchController.clear();
                  _updateFilteredCache();
                }
              });
              if (_searchExpanded) _searchFocus.requestFocus();
            },
          ),
        ],
      ),
      body: _loading && _scholarships.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
        onRefresh: _fetchData,
        color: _primary,
        child: _filteredCache.isEmpty
            ? ListView(children: const [SizedBox(height: 100), Center(child: Text("No Scholarships Found"))])
            : ListView.builder(
          cacheExtent: 1200,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _filteredCache.length,
          itemBuilder: (context, index) {
            return ScholarshipListTile(
              key: ValueKey(_filteredCache[index]['_id'] ?? index),
              s: _filteredCache[index],
              application: _applicationByScholarshipId[_filteredCache[index]['_id']?.toString()],
            );
          },
        ),
      ),
    );
  }
}

class ScholarshipListTile extends StatelessWidget {
  final Map<String, dynamic> s;
  final Map<String, dynamic>? application;
  static final _df = DateFormat('dd MMM, yyyy');

  const ScholarshipListTile({super.key, required this.s, required this.application});

  @override
  Widget build(BuildContext context) {
    final bool isApplied = application != null;
    final DateTime? deadlineDate = DateTime.tryParse(s['deadline']?.toString() ?? '');
    final bool isClosed = !(s['isActive'] ?? true) || (deadlineDate != null && deadlineDate.isBefore(DateTime.now()));

    final String type = (s['type'] ?? s['scholarshipType'] ?? 'Full Funded').toString().toUpperCase();
    final String thumb = (s['image'] ?? s['thumbnail'] ?? s['logo'])?.toString() ?? '';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => ScholarshipDetailScreen(scholarship: s)));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image Box
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: UiHelper.buildImage(ApiService.getUploadUrl(thumb), width: 75, height: 75, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                // Content Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(type,
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF2E8B57)),
                                overflow: TextOverflow.ellipsis),
                          ),
                          // High-Visibility Status Badge
                          _buildStatusBadge(isClosed, isApplied, application?['status']),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Title with 2-line overflow protection
                      Text(
                        s['title'] ?? 'Scholarship Program',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF10231A), height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['university_name'] ?? 'University Name',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Deadline display
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 12, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              deadlineDate != null ? "Deadline: ${_df.format(deadlineDate)}" : "No Deadline",
                              style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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

  Widget _buildStatusBadge(bool isClosed, bool isApplied, String? apiStatus) {
    String label = "APPLY";
    Color color = const Color(0xFFF97316); // Default: Apply Now (Orange)

    final status = apiStatus?.toLowerCase().trim();

    if (status == 'selected') {
      label = "SELECTED"; color = Colors.green;
    } else if (status == 'rejected') {
      label = "REJECTED"; color = Colors.red;
    } else if (isClosed) {
      label = "CLOSED"; color = const Color(0xFF64748B); // Grey
    } else if (isApplied) {
      label = "APPLIED"; color = const Color(0xFF2E8B57); // Dark Green
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8)
      ),
      child: Text(
          label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3)
      ),
    );
  }
}