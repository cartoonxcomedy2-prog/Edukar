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

class UniversityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> university;
  const UniversityDetailScreen({super.key, required this.university});

  @override
  State<UniversityDetailScreen> createState() => _UniversityDetailScreenState();
}

class _UniversityDetailScreenState extends State<UniversityDetailScreen> {
  late Map<String, dynamic> _currentUni;
  String _lastUniFingerprint = '';
  String _lastApplicationFingerprint = '';
  StreamSubscription? _updateSubscription;
  final ValueNotifier<bool> _isDescriptionExpanded = ValueNotifier<bool>(false);
  bool _isApplying = false;
  Uint8List? _preDecodedThumb;
  Map<String, dynamic>? _selectedProgram;
  String? _selectedProgramKey;
  String? _selectedProgramType;
  final GlobalKey _programsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUni = widget.university;
    _lastUniFingerprint = _uniFingerprint(_currentUni);
    _lastApplicationFingerprint = _applicationFingerprint();
    _preDecodeImage();
    _updateSubscription = ApiService.onDataUpdated.listen((_) {
      if (mounted) _refreshLocalData();
    });
    unawaited(_refreshFromNetwork());
  }

  void _refreshLocalData() {
    final updated = ApiService.allUniversities.firstWhere(
      (u) => u['_id'] == widget.university['_id'],
      orElse: () => null,
    );
    final nextUniFingerprint = updated != null
        ? _uniFingerprint(updated)
        : _lastUniFingerprint;
    final nextApplicationFingerprint = _applicationFingerprint();
    final shouldUpdateUniversity =
        updated != null && nextUniFingerprint != _lastUniFingerprint;
    final shouldUpdateApplication =
        nextApplicationFingerprint != _lastApplicationFingerprint;
    if (!shouldUpdateUniversity && !shouldUpdateApplication) return;
    if (!mounted) return;

    setState(() {
      if (shouldUpdateUniversity) {
        _currentUni = updated;
        _lastUniFingerprint = nextUniFingerprint;
      }
      _lastApplicationFingerprint = nextApplicationFingerprint;
    });
    if (shouldUpdateUniversity) {
      _preDecodeImage();
    }
  }

  Future<void> _refreshFromNetwork() async {
    try {
      await ApiService.fetchUniversities(forceRefresh: true);
    } catch (_) {}
    if (mounted) _refreshLocalData();
  }

  Map<String, dynamic>? _linkedApplication() {
    final applications = ApiService.currentUser?['applications'];
    if (applications is! List) return null;
    for (final raw in applications) {
      if (raw is! Map) continue;
      if (raw['type']?.toString().toLowerCase() != 'university') continue;
      final isReapplyEligible =
          raw['isReapplyEligible'] == true ||
          raw['isReapplyEligible']?.toString().toLowerCase() == 'true';
      if (isReapplyEligible) continue;
      final uni = raw['university'];
      if (uni is Map &&
          uni['_id']?.toString() == _currentUni['_id']?.toString()) {
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

  String _uniFingerprint(Map<String, dynamic> uni) {
    final programs = uni['programs'] as List? ?? const [];
    return '${uni['_id'] ?? ''}|${uni['updatedAt'] ?? ''}|${programs.length}|${programs.hashCode}';
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _isDescriptionExpanded.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _preDecodeImage() async {
    final thumb =
        (_currentUni['thumbnail'] ?? _currentUni['logo'])?.toString() ?? '';
    if (thumb.startsWith('data:image')) {
      try {
        final decoded = await compute(base64Decode, thumb.split(',').last);
        if (mounted) setState(() => _preDecodedThumb = decoded);
      } catch (e) {
        debugPrint('Image Error: $e');
      }
    }
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

  String _formatMoney(dynamic amount) {
    final raw = amount?.toString() ?? '';
    if (raw.isEmpty || raw == '0' || raw == '0.0') return 'Free';
    final currency =
        _currentUni['currency'] ?? _currentUni['feeCurrency'] ?? '';
    final formatted = NumberFormat.decimalPattern().format(
      num.tryParse(raw.replaceAll(',', '')) ?? 0,
    );
    final prefix = (currency?.toString().trim().isNotEmpty ?? false)
        ? '$currency '
        : '';
    return '$prefix$formatted';
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
    final all = _currentUni['programs'] as List? ?? [];
    return all.where((p) {
      final pType = (p['type'] ?? '').toString().toLowerCase();
      if (type.toLowerCase() == 'bachelor') {
        return pType.contains('bachelor') || pType == 'bs';
      }
      if (type.toLowerCase() == 'master') {
        return pType.contains('master') || pType == 'ms';
      }
      if (type.toLowerCase() == 'phd') {
        return pType.contains('phd');
      }
      return pType.contains(type.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uni = _currentUni;
    final deadline = DateTime.tryParse((uni['deadline'] ?? '').toString());
    final bool isClosed =
        !(uni['isActive'] ?? true) ||
        (deadline != null && deadline.isBefore(DateTime.now()));
    final heroHeight = (MediaQuery.of(context).size.width * 0.45).clamp(
      220.0,
      320.0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        key: PageStorageKey<String>(
          'university_detail_scroll_${_currentUni['_id'] ?? ''}',
        ),
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        controller: _scrollController,
        cacheExtent: 240,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            expandedHeight: heroHeight,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black38,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: RepaintBoundary(
                child: _preDecodedThumb != null
                    ? Image.memory(_preDecodedThumb!, fit: BoxFit.cover)
                    : ((uni['thumbnail'] ?? uni['logo']) != null
                          ? CachedNetworkImage(
                              imageUrl: ApiService.getFullUrl(
                                uni['thumbnail'] ?? uni['logo'],
                              ),
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              memCacheWidth: 900,
                              memCacheHeight: 520,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholderFadeInDuration: Duration.zero,
                            )
                          : Container(color: const Color(0xFF2E8B57))),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(uni),
                    const SizedBox(height: 24),
                    _buildAboutSection(uni['description']),

                    Container(
                      key: _programsKey,
                      child: _buildExpandableSection(
                        title: 'Available Programs',
                        icon: Icons.school_outlined,
                        content: _buildTabbedView(isFee: false),
                      ),
                    ),

                    _buildExpandableSection(
                      title: 'Fee Structure',
                      icon: Icons.account_balance_wallet_outlined,
                      content: _buildTabbedView(isFee: true),
                    ),

                    _buildExpandableSection(
                      title: 'Eligibility Criteria',
                      icon: Icons.assignment_turned_in_outlined,
                      content: _buildSectionText(
                        uni['eligibility'],
                        emptyMessage:
                            'No eligibility criteria available at the moment.',
                      ),
                    ),

                    _buildExpandableSection(
                      title: 'Scholarship Details',
                      icon: Icons.card_membership_outlined,
                      content: _buildSectionText(
                        uni['scholarshipDetails'],
                        emptyMessage: 'No scholarship available at the moment.',
                      ),
                    ),

                    _buildExpandableSection(
                      title: 'Contact Info',
                      icon: Icons.contact_phone_outlined,
                      content: _buildContactInfoSection(uni['contactInfo']),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isClosed, uni),
    );
  }

  String _normalizeType(String? type) {
    if (type == null) return 'PUBLIC';
    final t = type.trim().toUpperCase();
    if (t == 'GENERAL' || t.isEmpty) return 'PUBLIC';
    if (t == 'SEMI-GOVERNMENT') return 'SEMI-PUBLIC';
    return t;
  }

  Widget _buildHeader(Map<String, dynamic> uni) {
    final String type = _normalizeType(uni['universityType'] ?? uni['type']);
    final String? website = uni['website'];
    final String? address = uni['address'];
    final String? testDate = _formatOptionalDate(
      uni['testDate'] ?? uni['test_date'],
    );
    final String? interviewDate = _formatOptionalDate(
      uni['interviewDate'] ?? uni['interview_date'],
    );
    String locationString = '';
    if (address != null && address.trim().isNotEmpty) {
      locationString = address.trim();
    } else {
      final parts = [uni['city']?.toString().trim(), uni['country']?.toString().trim()]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      locationString = parts.join(', ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF475569),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          uni['name'] ?? '',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF10231A),
          ),
        ),
        const SizedBox(height: 10),

        // Location Row
        if (locationString.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: Color(0xFF486252),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationString,
                  style: const TextStyle(
                    color: Color(0xFF486252),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

        // Website Row (Optional)
        if (website != null && website.isNotEmpty) ...[
          const SizedBox(height: 8),
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

        const SizedBox(height: 24),
        Wrap(
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
                  _formatDate(uni['deadline']),
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
                  _statItem(
                    'Interview Date',
                    interviewDate,
                    const Color(0xFF2E8B57),
                  ),
                ],
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.payments_rounded,
                  size: 16,
                  color: Color(0xFF2E8B57),
                ),
                const SizedBox(width: 8),
                _statItem(
                  'App Fee',
                  _formatMoney(uni['applicationFee'] ?? uni['applicationFees']),
                  const Color(0xFF2E8B57),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabbedView({required bool isFee}) {
    final bs = _getFilteredProgs('bachelor');
    final ms = _getFilteredProgs('master');
    final phd = _getFilteredProgs('phd');

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFee) ...[
            const Text(
              'Tap a program to select it before applying.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
          ],
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
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: TabBarView(
              physics: const ClampingScrollPhysics(),
              children: [
                _buildList(bs, isFee),
                _buildList(ms, isFee),
                _buildList(phd, isFee),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> items, bool isFee) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isFee
              ? 'No fee structure available at this moment.'
              : 'No programs available at this moment.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      physics: const ClampingScrollPhysics(),
      primary: false,
      cacheExtent: 240,
      itemBuilder: (context, index) {
        final raw = items[index];
        final item = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final name = item['name'] ?? '';
        final duration = item['duration'] ?? 'N/A';
        final key = _programKey(item);
        final bool selectable = !isFee;
        final bool isSelected = selectable && key == _selectedProgramKey;

        if (isFee) {
          final fee =
              item['feeAmount'] ??
              item['semesterFee'] ??
              item['annualFee'] ??
              '0';
          final structure =
              item['feeStructure'] ??
              item['feeType'] ??
              (item['semesterFee'] != null ? 'Per Semester' : 'Per Year');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: $duration',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatMoney(fee),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF2E8B57),
                        ),
                        textAlign: TextAlign.right,
                        softWrap: true,
                      ),
                      Text(
                        structure.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.right,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return InkWell(
          onTap: () => _selectProgram(item),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEAF7EE)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: $duration',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
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

  Widget _statItem(String l, String v, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        v,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
    ],
  );

  Widget _buildAboutSection(String? desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About University',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder(
          valueListenable: _isDescriptionExpanded,
          builder: (context, expanded, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desc ?? '',
                maxLines: expanded ? null : 2,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () => _isDescriptionExpanded.value = !expanded,
                child: Text(
                  expanded ? 'Show Less' : 'See More',
                  style: const TextStyle(
                    color: Color(0xFF2E8B57),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildSectionText(dynamic text, {required String emptyMessage}) {
    final value = text?.toString().trim() ?? '';
    if (value.isEmpty) {
      return Text(
        emptyMessage,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      value,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF475569),
        height: 1.5,
      ),
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
    final String? contactBox = _currentUni['contact'];
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

  Widget _buildBottomBar(bool isClosed, Map<String, dynamic> uni) {
    final applications = ApiService.currentUser?['applications'] as List? ?? [];
    final app = applications.firstWhere(
      (a) =>
          a['type']?.toString().toLowerCase() == 'university' &&
          !(a['isReapplyEligible'] == true ||
              a['isReapplyEligible']?.toString().toLowerCase() == 'true') &&
          a['university']?['_id'] == uni['_id'],
      orElse: () => null,
    );
    final applied = app != null;
    final appStatus = (app?['status'] ?? '').toString().toLowerCase().trim();
    final isSelected = appStatus == 'selected';
    final isRejected = appStatus == 'rejected';
    final showTrack = applied && !isSelected && !isRejected;

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
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
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleApply() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final allPrograms = _currentUni['programs'] as List? ?? [];
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
        universityId: _currentUni['_id'],
        type: 'University',
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
