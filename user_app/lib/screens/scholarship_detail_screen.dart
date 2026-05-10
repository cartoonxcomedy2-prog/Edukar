import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/application_document_guard.dart';
import '../services/api_service.dart';
import './application_detail_screen.dart';

class ScholarshipDetailScreen extends StatefulWidget {
  final Map<String, dynamic> scholarship;
  const ScholarshipDetailScreen({super.key, required this.scholarship});

  @override
  State<ScholarshipDetailScreen> createState() =>
      _ScholarshipDetailScreenState();
}

class _ScholarshipDetailScreenState extends State<ScholarshipDetailScreen> {
  late Map<String, dynamic> _currentSch;
  String _lastSchFingerprint = '';
  String _lastApplicationFingerprint = '';
  StreamSubscription? _updateSubscription;
  Uint8List? _preDecodedThumb;

  final ValueNotifier<bool> _isDescriptionExpanded = ValueNotifier<bool>(false);
  bool _isApplying = false;
  Map<String, dynamic>? _selectedProgram;
  String? _selectedProgramKey;
  String? _selectedProgramType;
  final GlobalKey _programsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentSch = widget.scholarship;
    _lastSchFingerprint = _schFingerprint(_currentSch);
    _lastApplicationFingerprint = _applicationFingerprint();
    _decodeInlineThumbAsync(_currentSch);
    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      if (mounted) _refreshLocalData();
    });
    unawaited(_refreshFromNetwork());
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _isDescriptionExpanded.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshLocalData() {
    final updated = ApiService.allScholarships.firstWhere(
      (s) => s['_id'] == widget.scholarship['_id'],
      orElse: () => null,
    );
    final nextScholarshipFingerprint = updated != null
        ? _schFingerprint(updated)
        : _lastSchFingerprint;
    final nextApplicationFingerprint = _applicationFingerprint();
    final shouldUpdateScholarship =
        updated != null && nextScholarshipFingerprint != _lastSchFingerprint;
    final shouldUpdateApplication =
        nextApplicationFingerprint != _lastApplicationFingerprint;

    if (!shouldUpdateScholarship && !shouldUpdateApplication) return;
    if (!mounted) return;

    setState(() {
      if (shouldUpdateScholarship) {
        _currentSch = updated;
        _lastSchFingerprint = nextScholarshipFingerprint;
        _decodeInlineThumbAsync(updated);
      }
      _lastApplicationFingerprint = nextApplicationFingerprint;
    });
  }

  Future<void> _refreshFromNetwork() async {
    try {
      await ApiService.fetchScholarships(forceRefresh: true);
    } catch (_) {}
    if (mounted) _refreshLocalData();
  }

  Map<String, dynamic>? _linkedApplication() {
    final applications = ApiService.currentUser?['applications'];
    if (applications is! List) return null;
    for (final raw in applications) {
      if (raw is! Map) continue;
      if (raw['type']?.toString().toLowerCase() != 'scholarship') continue;
      final isReapplyEligible =
          raw['isReapplyEligible'] == true ||
          raw['isReapplyEligible']?.toString().toLowerCase() == 'true';
      if (isReapplyEligible) continue;
      final scholarship = raw['scholarship'];
      if (scholarship is Map &&
          scholarship['_id']?.toString() == _currentSch['_id']?.toString()) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return null;
  }

  String _applicationFingerprint() {
    final app = _linkedApplication();
    if (app == null) return 'none';
    return '${app['_id'] ?? ''}|${app['status'] ?? ''}|${app['updatedAt'] ?? ''}|'
        '${app['testDate'] ?? ''}|${app['interviewDate'] ?? ''}|'
        '${app['admitCard'] ?? ''}|${app['offerLetter'] ?? ''}';
  }

  String _schFingerprint(Map<String, dynamic> sch) {
    final programs = sch['programs'] as List? ?? const [];
    final steps = sch['applicationSteps'] as List? ?? const [];
    return '${sch['_id'] ?? ''}|${sch['updatedAt'] ?? ''}|${sch['deadline'] ?? ''}|'
        '${sch['isActive'] ?? ''}|${sch['testDate'] ?? ''}|${sch['interviewDate'] ?? ''}|'
        '${programs.length}|${steps.length}';
  }

  String _thumbSource(Map<String, dynamic> sch) {
    return (sch['image'] ?? sch['thumbnail'] ?? sch['logo'])?.toString() ?? '';
  }

  Future<void> _decodeInlineThumbAsync(Map<String, dynamic> sch) async {
    final raw = _thumbSource(sch);
    if (!raw.startsWith('data:image')) return;
    try {
      final parts = raw.split(',');
      if (parts.length > 1) {
        final decoded = await compute(base64Decode, parts.last);
        if (mounted) setState(() => _preDecodedThumb = decoded);
      }
    } catch (_) {}
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'No Deadline';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  String? _formatOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return DateFormat('dd MMM yyyy').format(value.toLocal());
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
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

  String _programKey(Map<String, dynamic> program) {
    final name = (program['name'] ?? program['programName'] ?? '')
        .toString()
        .trim();
    final type = (program['type'] ?? program['programType'] ?? '')
        .toString()
        .trim();
    final duration = (program['duration'] ?? '').toString().trim();
    return '$name|$type|$duration';
  }

  Map<String, dynamic>? _selectedProgramPayload() {
    final program = _selectedProgram;
    if (program == null) return null;
    final name = (program['name'] ?? program['programName'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty) return null;
    final type = (program['type'] ?? program['programType'] ?? '')
        .toString()
        .trim();
    final duration = (program['duration'] ?? '').toString().trim();
    final payload = <String, dynamic>{'programName': name};
    if (type.isNotEmpty) payload['programType'] = type;
    if (duration.isNotEmpty) payload['duration'] = duration;
    return payload;
  }

  void _selectProgram(Map<String, dynamic> program) {
    final normalized = {
      'name': program['name'] ?? program['programName'] ?? '',
      'type':
          program['type'] ?? program['programType'] ?? program['level'] ?? '',
      'duration': program['duration'] ?? '',
    };
    final type = normalized['type'].toString().toLowerCase().trim();
    setState(() {
      _selectedProgram = normalized;
      _selectedProgramKey = _programKey(normalized);
      _selectedProgramType = type;
    });
  }

  List<dynamic> _getFilteredProgs(String type) {
    final all = _currentSch['programs'] as List? ?? [];
    return all.where((p) {
      final pType = (p['type'] ?? '').toString().toLowerCase();
      if (type.toLowerCase() == 'bs' || type.toLowerCase() == 'bachelor') {
        return pType.contains('bachelor') || pType == 'bs';
      } else if (type.toLowerCase() == 'ms' || type.toLowerCase() == 'master') {
        return pType.contains('master') || pType == 'ms';
      } else if (type.toLowerCase() == 'phd') {
        return pType.contains('phd');
      }
      return pType.contains(type.toLowerCase());
    }).toList();
  }

  String _programHeaderSummary(Map<String, dynamic> scholarship) {
    final rawPrograms = scholarship['programs'];
    if (rawPrograms is! List || rawPrograms.isEmpty) {
      return '';
    }

    final names = rawPrograms
        .whereType<Map>()
        .map(
          (item) =>
              (item['name'] ?? item['programName'] ?? '').toString().trim(),
        )
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1} more';
  }

  @override
  Widget build(BuildContext context) {
    final sch = _currentSch;
    final deadline = DateTime.tryParse((sch['deadline'] ?? '').toString());
    final bool isClosed =
        !(sch['isActive'] ?? true) ||
        (deadline != null && deadline.isBefore(DateTime.now()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        key: PageStorageKey<String>(
          'scholarship_detail_scroll_${_currentSch['_id'] ?? ''}',
        ),
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        controller: _scrollController,
        cacheExtent: 800,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImage(sch),
                  if (_thumbSource(sch).isNotEmpty) const SizedBox(height: 18),
                  _buildHeader(sch),
                  const SizedBox(height: 24),
                  _buildQuickStats(sch),
                  const SizedBox(height: 24),
                  _buildAboutSection(sch['description']),
                  const SizedBox(height: 24),

                  Container(
                    key: _programsKey,
                    child: _buildExpandableSection(
                      title: 'Available Programs',
                      icon: Icons.school_outlined,
                      content: _buildTabbedPrograms(),
                    ),
                  ),

                  _buildExpandableSection(
                    title: 'Financial Coverage',
                    icon: Icons.account_balance_wallet_outlined,
                    content: _buildCoverageList(sch['coverage'] ?? []),
                  ),
                  _buildExpandableSection(
                    title: 'Eligibility Criteria',
                    icon: Icons.assignment_turned_in_outlined,
                    content: _buildEligibility(sch['eligibility']),
                  ),
                  _buildExpandableSection(
                    title: 'Provider Info',
                    icon: Icons.business_center_outlined,
                    content: _buildProviderInfo(sch),
                  ),
                  _buildExpandableSection(
                    title: 'Contact Info',
                    icon: Icons.contact_phone_outlined,
                    content: _buildContactInfoSection(sch['contactInfo']),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isClosed, sch['_id']),
    );
  }

  Widget _buildHeroImage(Map<String, dynamic> sch) {
    final raw = _thumbSource(sch);
    if (raw.trim().isEmpty) return const SizedBox.shrink();

    final Widget image = _preDecodedThumb != null
        ? Image.memory(_preDecodedThumb!, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: ApiService.getFullUrl(raw),
            fit: BoxFit.cover,
            memCacheWidth: 900,
            memCacheHeight: 520,
            placeholder: (context, url) =>
                Container(color: const Color(0xFFEAF7EE)),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFFEAF7EE),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF2E8B57),
                size: 48,
              ),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: 16 / 9, child: image),
    );
  }

  Widget _buildHeader(Map<String, dynamic> sch) {
    final String? website = sch['website'];
    final String programSummary = _programHeaderSummary(sch);
    String locationString = '';
    if (sch['address'] != null && sch['address'].toString().trim().isNotEmpty) {
      locationString = sch['address'].toString().trim();
    } else {
      final parts = [sch['city']?.toString().trim(), sch['country']?.toString().trim()]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      locationString = parts.join(', ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sch['title'] ?? 'Scholarship Detail',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (locationString.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Color(0xFF486252),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationString,
                  style: const TextStyle(
                    color: Color(0xFF486252),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        if (programSummary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 16,
                color: Color(0xFF486252),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  programSummary,
                  style: const TextStyle(
                    color: Color(0xFF486252),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (website != null && website.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final url = Uri.parse(
                website.startsWith('http') ? website : 'https://$website',
              );
              if (await canLaunchUrl(url)) {
                launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: Color(0xFF2E8B57),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    website
                        .replaceAll('https://', '')
                        .replaceAll('http://', ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2E8B57),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabbedPrograms() {
    final bs = _getFilteredProgs('BS');
    final ms = _getFilteredProgs('MS');
    final phd = _getFilteredProgs('PhD');
    if (bs.isEmpty && ms.isEmpty && phd.isEmpty) {
      return const Text(
        'No programs available at this moment.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tap a program to select it before applying.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            labelColor: const Color(0xFF2E8B57),
            unselectedLabelColor: const Color(0xFF486252),
            indicatorColor: const Color(0xFF2E8B57),
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: "Bachelor (${bs.length})"),
              Tab(text: "Master (${ms.length})"),
              Tab(text: "PhD (${phd.length})"),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: TabBarView(
              physics: const ClampingScrollPhysics(),
              children: [
                _buildSimpleProgList(bs),
                _buildSimpleProgList(ms),
                _buildSimpleProgList(phd),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleProgList(List<dynamic> progs) {
    if (progs.isEmpty) {
      return const Center(
        child: Text(
          'No programs available at this moment.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: progs.length,
      physics: const ClampingScrollPhysics(),
      primary: false,
      cacheExtent: 600,
      itemBuilder: (context, index) {
        final raw = progs[index];
        final item = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final name = item['name'] ?? '';
        final duration = item['duration'] ?? 'N/A';
        final key = _programKey(item);
        final bool isSelected = key == _selectedProgramKey;

        return InkWell(
          onTap: () => _selectProgram(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEAF7EE)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${index + 1}.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: $duration',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF2E8B57),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverageList(List<dynamic> coverage) {
    if (coverage.isEmpty) {
      return const Text(
        'No scholarship details available at this moment.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Column(
      children: coverage.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF7EE),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E8B57),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> sch) {
    final testDate = _formatOptionalDate(sch['testDate'] ?? sch['test_date']);
    final interviewDate = _formatOptionalDate(
      sch['interviewDate'] ?? sch['interview_date'],
    );

    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 8),
            _statItem(
              'Deadline',
              _formatDate(sch['deadline']),
              Colors.redAccent,
            ),
          ],
        ),
        if (testDate != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.quiz_rounded,
                size: 16,
                color: Color(0xFF2E8B57),
              ),
              const SizedBox(width: 8),
              _statItem('Test Date', testDate, const Color(0xFF2E8B57)),
            ],
          ),
        if (interviewDate != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                size: 16,
                color: Color(0xFF2E8B57),
              ),
              const SizedBox(width: 8),
              _statItem('Interview', interviewDate, const Color(0xFF2E8B57)),
            ],
          ),
      ],
    );
  }

  Widget _statItem(String label, String val, Color col) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        val,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
    ],
  );

  Widget _buildAboutSection(String? desc) {
    return ValueListenableBuilder(
      valueListenable: _isDescriptionExpanded,
      builder: (context, expanded, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            desc ?? '',
            maxLines: expanded ? null : 3,
            style: const TextStyle(
              color: Color(0xFF475569),
              height: 1.5,
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: () => _isDescriptionExpanded.value = !expanded,
            child: Text(
              expanded ? 'Show Less' : 'Read More',
              style: const TextStyle(
                color: Color(0xFF2E8B57),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          iconColor: const Color(0xFF2E8B57),
          leading: Icon(icon, color: const Color(0xFF2E8B57), size: 20),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF10231A),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibility(Map<String, dynamic>? eli) {
    final minPercentage = eli?['minPercentage'];
    final description = (eli?['description'] ?? '').toString().trim();
    final hasMinPercentage =
        minPercentage != null && '$minPercentage'.trim().isNotEmpty;
    final hasDescription = description.isNotEmpty;

    if (!hasMinPercentage && !hasDescription) {
      return const Text(
        'No eligibility criteria available at this moment.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMinPercentage)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Min Percentage'),
              Text(
                '$minPercentage%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        if (hasDescription) ...[
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ],
      ],
    );
  }

  Widget _buildProviderInfo(Map<String, dynamic> sch) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Organization'),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            sch['provider'] ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _normalizeContactInfo(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is! Map) return null;
          final map = Map<String, dynamic>.from(item);
          final email = (map['email'] ?? '').toString().trim();
          final phone = (map['phone'] ?? '').toString().trim();
          if (email.isEmpty && phone.isEmpty) return null;
          return {'email': email, 'phone': phone};
        })
        .whereType<Map<String, String>>()
        .toList();
  }

  Widget _buildContactInfoSection(dynamic raw) {
    final String? contactBox = _currentSch['contact'];
    final contacts = _normalizeContactInfo(raw);

    if (contacts.isEmpty && (contactBox == null || contactBox.trim().isEmpty)) {
      return const Text(
        'No contact info available at the moment.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contacts.isNotEmpty) const SizedBox(height: 12),
        ...contacts.map((contact) {
          final email = contact['email'] ?? '';
          final phone = contact['phone'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final uri = Uri(scheme: 'mailto', path: email);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Color(0xFF2E8B57),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(
                              color: Color(0xFF2E8B57),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (phone.isNotEmpty) ...[
                  if (email.isNotEmpty) const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final uri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.call_outlined,
                          size: 16,
                          color: Color(0xFF2E8B57),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phone,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar(bool isClosed, String id) {
    final applications = ApiService.currentUser?['applications'] as List? ?? [];
    final app = applications.firstWhere(
      (a) =>
          a['type']?.toString().toLowerCase() == 'scholarship' &&
          !(a['isReapplyEligible'] == true ||
              a['isReapplyEligible']?.toString().toLowerCase() == 'true') &&
          a['scholarship']?['_id'] == id,
      orElse: () => null,
    );
    final hasApplied = app != null;
    final appStatus = (app?['status'] ?? '').toString().toLowerCase().trim();
    final isSelected = appStatus == 'selected';
    final isRejected = appStatus == 'rejected';
    final showTrack = hasApplied && !isSelected && !isRejected;

    final buttonText = isSelected
        ? 'Selected'
        : isRejected
        ? 'Rejected'
        : showTrack
        ? 'Track Application'
        : (isClosed ? 'Closed' : 'Apply Now');

    final buttonColor = isSelected
        ? const Color(0xFF10B981) // Green
        : isRejected
        ? const Color(0xFFEF4444) // Red
        : showTrack
        ? const Color(0xFFF97316) // Orange for Track
        : (isClosed
              ? const Color(0xFFEAB308)
              : const Color(
                  0xFFF97316,
                )); // Yellow for Closed, Orange for Apply Now

    final onPressed = _isApplying
        ? null
        : (showTrack
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApplicationDetailScreen(application: app),
                  ),
                )
              : ((isClosed || isSelected || isRejected) ? null : _handleApply));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isApplying
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleApply() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final allPrograms = _currentSch['programs'] as List? ?? [];
    final selectedPayload = _selectedProgramPayload();
    if (allPrograms.isNotEmpty && selectedPayload == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please select a program first.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          margin: EdgeInsets.all(16),
        ),
      );
      final targetContext = _programsKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    final user = ApiService.currentUser;
    final selectedLevel = ApplicationDocumentGuard.resolveLevel(
      _selectedProgramType,
      fallbackName: _selectedProgram?['name']?.toString(),
    );
    final missingDocuments = ApplicationDocumentGuard.missingDocumentsForLevel(
      user: user,
      level: selectedLevel,
    );
    if (missingDocuments.isNotEmpty) {
      _showMissingDocAlert(
        ApplicationDocumentGuard.buildMissingDocumentsMessage(
          selectedLevel,
          missingDocuments,
        ),
      );
      return;
    }

    setState(() => _isApplying = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 35.0, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(color: Color(0xFF2E8B57), strokeWidth: 4),
              ),
              SizedBox(height: 24),
              Text('Please Wait...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              SizedBox(height: 8),
              Text('Submitting your application', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(seconds: 4));
      await ApiService.applyToOpportunity(
        scholarshipId: _currentSch['_id'],
        type: 'Scholarship',
        selectedPrograms: selectedPayload != null ? [selectedPayload] : [],
      );

      if (mounted) {
        Navigator.pop(context); // close loading
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 35.0, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 65),
                  SizedBox(height: 20),
                  Text('Applied Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text('Your application has been submitted.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context); // close success
          navigator.pop(); // go back
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if error occurs
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  void _showMissingDocAlert(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Missing Documents',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
              height: 1.35,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pushNamed(context, '/education-documents');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
