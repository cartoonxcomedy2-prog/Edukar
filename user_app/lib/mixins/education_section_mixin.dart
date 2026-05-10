import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../utils/ui_helper.dart';
import '../widgets/education_widgets.dart';

/// Shared mixin for all Education section pages.
/// Each section page mixes this in to reuse file-pick, view, download,
/// save, and common field-builder logic identically.
mixin EducationSectionMixin<T extends StatefulWidget> on State<T> {
  static const int maxPdfBytes = 9 * 1024 * 1024;
  static const String defaultCountry = 'Pakistan';

  static const Map<String, String> fileLabelByKey = {
    'idFile': 'national-id', 'fatherCnicFile': 'father-cnic',
    'matricTranscript': 'matric-transcript', 'matricCertificate': 'matric-certificate',
    'interTranscript': 'intermediate-transcript', 'interCertificate': 'intermediate-certificate',
    'bachTranscript': 'bachelor-transcript', 'bachCertificate': 'bachelor-certificate',
    'masterTranscript': 'masters-transcript', 'masterCertificate': 'masters-certificate',
    'passportPdf': 'passport', 'testTranscript': 'english-test-transcript',
    'cv': 'curriculum-vitae', 'recommendationLetter': 'recommendation-letter',
  };

  static const _routeSection = <String, String>{
    'idFile': 'nationalId', 'fatherCnicFile': 'personalInfo',
    'matricTranscript': 'matric', 'matricCertificate': 'matric',
    'interTranscript': 'intermediate', 'interCertificate': 'intermediate',
    'bachTranscript': 'bachelor', 'bachCertificate': 'bachelor',
    'masterTranscript': 'masters', 'masterCertificate': 'masters',
  };

  static const _routeField = <String, String>{
    'idFile': 'file', 'fatherCnicFile': 'fatherCnicFile',
    'matricTranscript': 'transcript', 'interTranscript': 'transcript',
    'bachTranscript': 'transcript', 'masterTranscript': 'transcript',
    'matricCertificate': 'certificate', 'interCertificate': 'certificate',
    'bachCertificate': 'certificate', 'masterCertificate': 'certificate',
  };

  final Map<String, dynamic> localFiles = {};
  bool isLoading = false;

  bool hasFile(dynamic v) {
    final s = v?.toString().trim().toLowerCase() ?? '';
    return s.isNotEmpty && s != 'null' && s != 'undefined' &&
        s != 'none' && s != 'n/a' && s != 'na' && s != '-';
  }

  String nested(dynamic src, List<String> path) {
    dynamic c = src;
    for (final k in path) { if (c is! Map) return ''; c = c[k]; }
    return c?.toString().trim() ?? '';
  }

  String dateFmt(dynamic raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? '' : (s.contains('T') ? s.split('T').first : s);
  }

  bool isMulti(String label) {
    final l = label.toLowerCase();
    return l.contains('address') || l.contains('previous university') ||
        l.contains('previous institute') || l.contains('school name') ||
        l.contains('college name') || l.contains('degree name');
  }

  void msg(String m, {bool ok = true}) {
    if (!mounted) return;
    UiHelper.showCenteredSnackBar(context, m, isSuccess: ok);
  }

  String sanitize(String v, {String fb = 'document'}) {
    final s = v.trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final lim = s.length > 60 ? s.substring(0, 60) : s;
    return lim.isEmpty ? fb : lim;
  }

  String ext(String? v, {String fb = '.pdf'}) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return fb;
    try {
      final parsed = Uri.tryParse(ApiService.getUploadUrl(raw)) ?? Uri.tryParse(raw);
      final p = parsed?.path.isNotEmpty == true ? parsed!.path : raw;
      final dot = p.lastIndexOf('.');
      if (dot >= 0 && dot < p.length - 1) {
        final e = p.substring(dot).toLowerCase();
        if (RegExp(r'^\.[a-z0-9]+$', caseSensitive: false).hasMatch(e)) return e;
      }
    } catch (_) {}
    return fb;
  }

  Future<void> pickFile(String key, String label, {bool enabled = true}) async {
    if (!enabled) return;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.first;
      final path = f.path?.trim() ?? '';
      final bytes = f.bytes;

      if (path.isEmpty && (bytes == null || bytes.isEmpty)) {
        msg('$label could not be read.', ok: false);
        return;
      }

      if (f.name.toLowerCase().endsWith('.pdf') && f.size > maxPdfBytes) {
        msg('$label PDF too large (max 9MB).', ok: false);
        return;
      }

      if (mounted) {
        setState(() {
          localFiles[key] = {
            'path': path,
            'name': f.name,
            'bytes': bytes,
            'size': f.size,
          };
        });
        msg('$label selected successfully!');
      }
    } catch (e) {
      debugPrint('Pick error: $e');
      if (mounted) msg('Could not pick file.', ok: false);
    }
  }

  Future<void> viewFile(String key, String? saved) async {
    final s = (saved ?? '').trim();
    if (s.isEmpty) { msg('No file available to view', ok: false); return; }

    final uid = ApiService.currentUser?['_id']?.toString().trim() ?? '';
    final sec = _routeSection[key] ?? '';
    final fld = _routeField[key] ?? key;
    final name = ApiService.currentUser?['name']?.toString().trim() ?? '';
    final user = name.isNotEmpty ? name : 'applicant';
    final label = fileLabelByKey[key] ?? key;
    final dlName = '${sanitize(user, fb: 'applicant')}-${sanitize(label, fb: key)}${ext(s)}';

    try {
      if (uid.isEmpty || sec.isEmpty) throw Exception('Missing path');
      msg('Opening file...');
      final bytes = await ApiService.downloadEducationDocumentBytes(
        userId: uid, section: sec, field: fld, downloadName: dlName,
      );
      final base = await getTemporaryDirectory();
      final file = File('${base.path}${Platform.pathSeparator}$dlName');
      await file.writeAsBytes(bytes, flush: true);
      final r = await OpenFilex.open(file.path);
      if (r.type != ResultType.done && mounted) msg('File saved at: ${file.path}');
    } catch (e) {
      debugPrint('View error: $e');
      final url = ApiService.getUploadUrl(s);
      if (url.isNotEmpty) {
        try {
          await launchUrlString(url, mode: LaunchMode.externalApplication);
        } catch (_) {
          if (mounted) msg('Could not open file.', ok: false);
        }
      } else {
        if (mounted) msg('Could not open file.', ok: false);
      }
    }
  }

  Future<void> downloadFile(String key, String? saved) async {
    final s = (saved ?? '').trim();
    if (s.isEmpty) { msg('No file available to download', ok: false); return; }

    final uid = ApiService.currentUser?['_id']?.toString().trim() ?? '';
    final sec = _routeSection[key] ?? '';
    final fld = _routeField[key] ?? key;
    final name = ApiService.currentUser?['name']?.toString().trim() ?? '';
    final user = name.isNotEmpty ? name : 'applicant';
    final label = fileLabelByKey[key] ?? key;
    final dlName = '${sanitize(user, fb: 'applicant')}-${sanitize(label, fb: key)}${ext(s)}';

    try {
      if (uid.isEmpty || sec.isEmpty) throw Exception('Missing path');
      msg('Downloading...');
      final bytes = await ApiService.downloadEducationDocumentBytes(
        userId: uid, section: sec, field: fld, downloadName: dlName,
      );
      final base = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${base.path}${Platform.pathSeparator}$dlName');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) msg('Downloaded: ${file.path}');
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) msg('Download failed.', ok: false);
    }
  }

  /// Get the full existing education map from the user profile
  Map<String, dynamic> getExistingEducation() {
    final edu = ApiService.currentUser?['education'];
    if (edu is Map) return Map<String, dynamic>.from(edu);
    return {};
  }

  /// Save education data, merging this section's data with existing
  Future<void> saveSection({
    Map<String, dynamic>? sectionEducation,
    String? address,
    String? state,
    String? city,
    String? fatherName,
    String? dateOfBirth,
  }) async {
    setState(() => isLoading = true);

    try {
      // Merge with existing education data
      final existing = getExistingEducation();
      final merged = sectionEducation != null ? {...existing, ...sectionEducation} : existing;

      await ApiService.updateProfile(
        education: merged,
        files: localFiles,
        address: address,
        state: state,
        city: city,
        fatherName: fatherName,
        dateOfBirth: dateOfBirth,
      );

      if (mounted) {
        msg('Documents saved successfully!');
        localFiles.clear();
        onDataSaved();
      }
    } catch (e) {
      if (mounted) {
        final m = e.toString()
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .replaceFirst(RegExp(r'^DioException:\s*'), '').trim();
        msg(m.isEmpty ? 'Error saving documents.' : m, ok: false);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Override in each section to reload data after save
  void onDataSaved();

  // ─── COMMON FIELD BUILDERS ──────────────────────────────────────────────────
  Widget buildField(
      String label,
      TextEditingController ctrl,
      IconData icon, {
      TextInputType? kt,
      bool enabled = true,
      bool readOnly = false,
      }) {
    final isLocked = readOnly;
    final multi = isMulti(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: eduSlate600,
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_rounded, size: 9, color: Color(0xFF92400E)),
                      SizedBox(width: 2),
                      Text('Locked', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            readOnly: !enabled || isLocked,
            keyboardType: multi ? TextInputType.multiline : kt,
            textInputAction: multi ? TextInputAction.newline : TextInputAction.next,
            minLines: 1,
            maxLines: multi ? 3 : 1,
            textAlignVertical: multi ? TextAlignVertical.top : TextAlignVertical.center,
            scrollPadding: const EdgeInsets.only(bottom: 300),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isLocked ? eduSlate400 : eduSlate900,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              prefixIcon: Icon(icon, size: 16, color: isLocked ? eduSlate300 : eduSlate400),
              hintText: 'Enter $label',
              hintStyle: const TextStyle(fontSize: 12, color: eduSlate300),
              filled: true,
              fillColor: isLocked ? eduSlate100 : eduSlate50,
              border: eduOutlineBorder(),
              enabledBorder: eduOutlineBorder(c: eduSlate200),
              focusedBorder: eduOutlineBorder(c: eduSlate300),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDrop(
      String label,
      List<String> items,
      String? val,
      ValueChanged<String?> onChange,
      ) {
    final safe = items.contains(val) ? val : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: eduSlate600,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: safe,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: eduSlate400,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: eduSlate900,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: eduSlate400,
              ),
              hintText: 'Select $label',
              hintStyle: const TextStyle(fontSize: 12, color: eduSlate300),
              filled: true,
              fillColor: eduSlate50,
              border: eduOutlineBorder(),
              enabledBorder: eduOutlineBorder(c: eduSlate200),
              focusedBorder: eduOutlineBorder(c: eduSlate300),
            ),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false),
            onChanged: onChange,
          ),
        ],
      ),
    );
  }

  Widget buildYear(String label, String? val, ValueChanged<String?> onChange) {
    final safe = eduYears.contains(val) ? val : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: eduSlate600,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: safe,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: eduSlate400,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: eduSlate900,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              prefixIcon: const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: eduSlate400,
              ),
              hintText: 'Select Year',
              hintStyle: const TextStyle(fontSize: 12, color: eduSlate300),
              filled: true,
              fillColor: eduSlate50,
              border: eduOutlineBorder(),
              enabledBorder: eduOutlineBorder(c: eduSlate200),
              focusedBorder: eduOutlineBorder(c: eduSlate300),
            ),
            items: eduYearItems,
            onChanged: onChange,
          ),
        ],
      ),
    );
  }

  Widget buildToggle(String title, bool val, ValueChanged<bool> onChange) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: eduSlate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: eduSlate200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, size: 16, color: eduSlate500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: eduSlate900,
                ),
              ),
            ),
            Switch.adaptive(
              value: val,
              activeThumbColor: Colors.white,
              activeTrackColor: eduGreen,
              inactiveTrackColor: eduSlate300,
              onChanged: onChange,
            ),
          ],
        ),
      ),
    ),
  );

  Widget buildSaveBtn(String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: eduGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ),
  );

  Widget buildFp(String label, String key, String? saved, {bool enabled = true, bool locked = false}) => EduFilePicker(
    label: label,
    fieldKey: key,
    saved: saved,
    local: localFiles[key],
    enabled: enabled && !locked,
    locked: locked,
    onPick: (k, l) => pickFile(k, l, enabled: enabled && !locked),
    onView: viewFile,
    onDownload: downloadFile,
    onRemove: removeFile,
  );

  void removeFile(String key);

  /// Standard AppBar for section pages
  AppBar buildSectionAppBar(String title) => AppBar(
    title: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: eduSlate900,
      ),
    ),
    centerTitle: false,
    backgroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: eduSlate900,
      ),
      onPressed: () => Navigator.pop(context),
    ),
  );

  /// Standard page body wrapper
  Widget buildSectionBody(List<Widget> children) {
    return isLoading
        ? const Center(child: CircularProgressIndicator(color: eduGreen))
        : LayoutBuilder(
      builder: (context, constraints) {
        final hPad = constraints.maxWidth > 600 ? 24.0 : 16.0;
        final bottomPad = MediaQuery.of(context).padding.bottom + 100.0; // Added safe area + padding
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, bottomPad),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth > 800 ? 800 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
