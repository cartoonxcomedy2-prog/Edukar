import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── SHARED COLORS ──────────────────────────────────────────────────────────────
const eduGreen       = Color(0xFF2E8B57);
const eduSlate50     = Color(0xFFF8FAFC);
const eduSlate100    = Color(0xFFF1F5F9);
const eduSlate200    = Color(0xFFE2E8F0);
const eduSlate300    = Color(0xFFCBD5E1);
const eduSlate400    = Color(0xFF94A3B8);
const eduSlate500    = Color(0xFF64748B);
const eduSlate600    = Color(0xFF475569);
const eduSlate900    = Color(0xFF0F172A);
const eduGreenBorder = Color(0xFF86EFAC);
const eduGreenBg     = Color(0xFFF0FDF4);
const eduGreenText   = Color(0xFF15803D);
const eduGreenDark   = Color(0xFF166534);
const eduGreenPill   = Color(0xFFDCFCE7);
const eduRedBorder   = Color(0xFFFCA5A5);
const eduRedBg       = Color(0xFFFEF2F2);
const eduRedText     = Color(0xFFB91C1C);
const eduRedDark     = Color(0xFF991B1B);
const eduRedPill     = Color(0xFFFEE2E2);
const eduRed         = Color(0xFFDC2626);
const eduBlue        = Color(0xFF0EA5E9);
const eduTeal        = Color(0xFF0F766E);
const eduOrange      = Color(0xFFEA580C);

// ─── SHARED BORDER HELPER ───────────────────────────────────────────────────────
OutlineInputBorder eduOutlineBorder({Color c = Colors.transparent}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: c == Colors.transparent
          ? BorderSide.none
          : BorderSide(color: c, width: 1),
    );

// ─── SHARED YEAR DATA ───────────────────────────────────────────────────────────
final List<String> eduYears =
    List.generate(46, (i) => (1980 + i).toString(), growable: false);
final List<DropdownMenuItem<String>> eduYearItems =
    eduYears.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(growable: false);

// ─── FILE PICKER ROW ───────────────────────────────────────────────────────────
class EduFilePicker extends StatelessWidget {
  const EduFilePicker({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.saved,
    required this.local,
    required this.onPick,
    required this.onView,
    required this.onDownload,
    required this.onRemove,
    this.enabled = true,
    this.locked = false,
  });

  final String label, fieldKey;
  final String? saved;
  final dynamic local;
  final Future<void> Function(String, String) onPick;
  final Future<void> Function(String, String?) onView;
  final Future<void> Function(String, String?) onDownload;
  final void Function(String) onRemove;
  final bool enabled;
  final bool locked;

  bool get _hasSaved {
    final s = saved?.toString().trim().toLowerCase() ?? '';
    return s.isNotEmpty &&
        s != 'null' &&
        s != 'undefined' &&
        s != 'none' &&
        s != 'n/a' &&
        s != 'na' &&
        s != '-';
  }

  String get _displayName {
    if (local != null) {
      if (local is Map) {
        final n = (local['name'] ?? '').toString().trim();
        if (n.isNotEmpty) return n;
        final p = (local['path'] ?? '').toString().trim();
        return p.isNotEmpty ? p.split(Platform.pathSeparator).last : 'Selected file';
      }
      final s = local.toString().trim();
      return s.isEmpty ? 'Selected file' : s.split(Platform.pathSeparator).last;
    }
    if (_hasSaved) {
      final clean = saved!.split('?').first;
      final base = clean.split(RegExp(r'[/\\]')).last;
      if (base.isEmpty) return 'Uploaded file';
      try {
        return Uri.decodeComponent(base);
      } catch (_) {
        return base;
      }
    }
    return 'No file selected';
  }

  @override
  Widget build(BuildContext context) {
    final up = local != null || _hasSaved;
    final bc = up ? eduGreenBorder : eduRedBorder;
    final ic = up ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: up ? eduGreenBg : eduRedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bc),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: bc),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        up ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        size: 18,
                        color: ic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: eduSlate900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (locked)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
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
                          ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: up ? eduGreenText : eduRedText,
                                ),
                              ),
                            ),
                            if (enabled && up)
                              GestureDetector(
                                onTap: () => onRemove(fieldKey),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.close_rounded, size: 14, color: eduRed),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: up ? eduGreenPill : eduRedPill,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        up ? 'Uploaded' : 'Missing',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: up ? eduGreenDark : eduRedDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (enabled)
                    EduBtn(
                      icon: (_hasSaved || local != null) ? Icons.edit_rounded : Icons.upload_file_rounded,
                      label: (_hasSaved || local != null) ? 'Change' : 'Upload',
                      color: (_hasSaved || local != null) ? eduOrange : eduGreen,
                      onTap: () {
                      HapticFeedback.lightImpact();
                      onPick(fieldKey, label);
                    },
                  ),
                  if (_hasSaved)
                    EduBtn(
                      icon: Icons.remove_red_eye_rounded,
                      label: 'View',
                      color: eduBlue,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onView(fieldKey, saved);
                      },
                    ),
                  if (enabled && (_hasSaved || local != null))
                    EduBtn(
                      icon: Icons.cancel_rounded,
                      label: 'Remove',
                      color: eduRed,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onRemove(fieldKey);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SMALL BUTTON ──────────────────────────────────────────────────────────────
class EduBtn extends StatelessWidget {
  const EduBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── REQUIREMENTS NOTE ─────────────────────────────────────────────────────────
class EduRequirementsNote extends StatelessWidget {
  const EduRequirementsNote({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFFEDD5),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.warning_rounded, color: eduOrange, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Important Requirements',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _b('Bachelor:', 'Personal Info + CNIC + Matric + Inter.'),
            const SizedBox(height: 6),
            _b("Master's:", 'Personal Info + CNIC + Matric + Inter + Bachelor.'),
            const SizedBox(height: 6),
            _b('PhD:', 'Personal Info + CNIC + Matric + Inter + Bachelor + Master.'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFFDBA74), height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.gpp_maybe_rounded, size: 16, color: eduRed),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Missing any required document will result in application rejection.',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _b(String t, String d) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Icon(Icons.circle, size: 5, color: eduOrange),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF7C2D12),
            ),
            children: [
              TextSpan(
                text: '$t ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: d,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
