import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/location_data.dart';
import '../widgets/education_widgets.dart';
import '../mixins/education_section_mixin.dart';

class EduPersonalInfoScreen extends StatefulWidget {
  const EduPersonalInfoScreen({super.key});
  @override
  State<EduPersonalInfoScreen> createState() => _EduPersonalInfoScreenState();
}

class _EduPersonalInfoScreenState extends State<EduPersonalInfoScreen>
    with EducationSectionMixin<EduPersonalInfoScreen> {

  final _fatherNameController          = TextEditingController();
  final _fatherContactNumberController = TextEditingController();
  final _fatherCnicNumberController    = TextEditingController();
  final _dateOfBirthController         = TextEditingController();
  final _idNumberController            = TextEditingController();
  final _addressController             = TextEditingController();
  String? _stateLived, _cityLived;
  String? _idSavedFile, _fatherCnicSavedFile;
  bool _hasApplied = false; // Lock identity fields after first application

  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final user = ApiService.currentUser;
    final edu = user?['education'];

    setState(() {
      _stateLived = user?['state']?.toString();
      _cityLived  = user?['city']?.toString();
      _addressController.text = user?['address']?.toString() ?? '';

      _fatherNameController.text = '';
      _fatherContactNumberController.text = '';
      _fatherCnicNumberController.text = '';
      _dateOfBirthController.text = '';
      _idNumberController.text = '';
      _idSavedFile = _fatherCnicSavedFile = null;

      if (edu != null) {
        final pi  = edu['personalInfo'] as Map? ?? {};
        final nid = edu['nationalId'];
        final nf  = nid is Map ? nid['file'] : null;
        final cf  = pi['fatherCnicFile'];

        _fatherNameController.text =
            (pi['fatherName']?.toString().trim().isNotEmpty == true
                ? pi['fatherName'] : user?['fatherName'])?.toString() ?? '';
        _fatherContactNumberController.text = pi['fatherContactNumber']?.toString() ?? '';
        _fatherCnicNumberController.text    = pi['fatherCnicNumber']?.toString() ?? '';
        _dateOfBirthController.text = dateFmt(pi['dateOfBirth'] ?? user?['dateOfBirth']);
        _idNumberController.text = nid is Map ? (nid['idNumber']?.toString() ?? '') : '';
        _idSavedFile         = hasFile(nf) ? nf.toString() : null;
        _fatherCnicSavedFile = hasFile(cf) ? cf.toString() : null;
      } else {
        _fatherNameController.text = user?['fatherName']?.toString() ?? '';
        _dateOfBirthController.text = dateFmt(user?['dateOfBirth']);
      }

      localFiles.clear();

      // Check if user has any applications → lock identity fields
      final apps = user?['applications'] as List? ?? [];
      _hasApplied = apps.isNotEmpty;
    });
  }

  @override
  void onDataSaved() => _loadData();

  @override
  void removeFile(String key) {
    setState(() {
      localFiles.remove(key);
      if (key == 'idFile') _idSavedFile = null;
      if (key == 'fatherCnicFile') _fatherCnicSavedFile = null;
    });
    msg('File removed. Tap Save to apply.', ok: false);
  }

  void _save() {
    final sectionEdu = <String, dynamic>{};
    if (!_hasApplied) {
      // Only allow identity updates when not locked
      sectionEdu['personalInfo'] = {
        'fatherName': _fatherNameController.text.trim(),
        'fatherContactNumber': _fatherContactNumberController.text.trim(),
        'fatherCnicNumber': _fatherCnicNumberController.text.trim(),
        'fatherCnicFile': _fatherCnicSavedFile,
        'dateOfBirth': _dateOfBirthController.text.trim(),
        'cnicNumber': _idNumberController.text.trim(),
      };
      sectionEdu['nationalId'] = {
        'idNumber': _idNumberController.text.trim(),
        'file': _idSavedFile,
      };
    }
    saveSection(
      sectionEducation: sectionEdu.isNotEmpty ? sectionEdu : null,
      address: _addressController.text.trim(),
      state: _stateLived,
      city: _cityLived,
      fatherName: _hasApplied ? null : _fatherNameController.text.trim(),
      dateOfBirth: _hasApplied ? null : _dateOfBirthController.text.trim(),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    DateTime init = DateTime(now.year - 18, now.month, now.day);
    final ex = _dateOfBirthController.text.trim();
    if (ex.isNotEmpty) {
      final p = DateTime.tryParse(ex);
      if (p != null) init = p;
    }

    final sel = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: eduGreen,
            onPrimary: Colors.white,
            onSurface: eduSlate900,
          ),
        ),
        child: child!,
      ),
    );

    if (sel != null && mounted) {
      setState(() {
        _dateOfBirthController.text =
        '${sel.year.toString().padLeft(4, '0')}-'
            '${sel.month.toString().padLeft(2, '0')}-'
            '${sel.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _fatherNameController.dispose();
    _fatherContactNumberController.dispose();
    _fatherCnicNumberController.dispose();
    _dateOfBirthController.dispose();
    _idNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eduSlate100,
      appBar: buildSectionAppBar('Personal & ID Info'),
      body: buildSectionBody([
        if (_hasApplied)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFFCD34D)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Identity Fields Locked',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF92400E))),
                      SizedBox(height: 2),
                      Text('CNIC, father details & ID documents are locked after submitting an application to prevent identity fraud.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFA16207), height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        buildField('Father Name', _fatherNameController, Icons.family_restroom_rounded, readOnly: _hasApplied),
        buildField(
          'Father Contact Number',
          _fatherContactNumberController,
          Icons.phone_outlined,
          kt: TextInputType.phone,
          readOnly: _hasApplied,
        ),
        // Date of Birth
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Date of Birth',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: eduSlate600,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _pickDob,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dateOfBirthController,
                    scrollPadding: const EdgeInsets.only(bottom: 300),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: eduSlate900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                      prefixIcon: const Icon(Icons.calendar_month_outlined, size: 16, color: eduSlate400),
                      suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 18, color: eduSlate400),
                      hintText: 'Select Date of Birth',
                      hintStyle: const TextStyle(fontSize: 12, color: eduSlate300),
                      filled: true,
                      fillColor: eduSlate50,
                      border: eduOutlineBorder(),
                      enabledBorder: eduOutlineBorder(c: eduSlate200),
                      focusedBorder: eduOutlineBorder(c: eduSlate300),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        buildDrop(
          'State / Province',
          LocationData.getStates(EducationSectionMixin.defaultCountry),
          _stateLived,
          (v) => setState(() { _stateLived = v; _cityLived = null; }),
        ),
        if (_stateLived != null && LocationData.getCities(EducationSectionMixin.defaultCountry, _stateLived!).isNotEmpty)
          buildDrop(
            'City',
            LocationData.getCities(EducationSectionMixin.defaultCountry, _stateLived!),
            _cityLived,
            (v) => setState(() => _cityLived = v),
          ),
        buildField('Home Address', _addressController, Icons.home_work_outlined),
        buildField(
          'ID / CNIC Number',
          _idNumberController,
          Icons.badge_outlined,
          readOnly: _hasApplied,
        ),
        buildFp(
          'National ID Card File',
          'idFile',
          _idSavedFile,
          locked: _hasApplied,
        ),
        buildField(
          'Father CNIC Number',
          _fatherCnicNumberController,
          Icons.badge_outlined,
          readOnly: _hasApplied,
        ),
        buildFp(
          'Father CNIC File',
          'fatherCnicFile',
          _fatherCnicSavedFile,
          locked: _hasApplied,
        ),
        buildSaveBtn('Save Personal & ID Info', _save),
      ]),
    );
  }
}
