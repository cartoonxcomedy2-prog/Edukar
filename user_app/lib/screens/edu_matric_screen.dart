import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/location_data.dart';
import '../widgets/education_widgets.dart';
import '../mixins/education_section_mixin.dart';

class EduMatricScreen extends StatefulWidget {
  const EduMatricScreen({super.key});
  @override
  State<EduMatricScreen> createState() => _EduMatricScreenState();
}

class _EduMatricScreenState extends State<EduMatricScreen>
    with EducationSectionMixin<EduMatricScreen> {

  String? _matricYear, _matricState, _matricCity;
  final _matricSchoolController = TextEditingController();
  final _matricGradeController  = TextEditingController();
  String? _matricSavedTranscript, _matricSavedCertificate;

  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final edu = ApiService.currentUser?['education'];
    setState(() {
      _matricState = _matricCity = _matricYear = null;
      _matricSchoolController.text = '';
      _matricGradeController.text = '';
      _matricSavedTranscript = _matricSavedCertificate = null;

      if (edu != null) {
        final ma = edu['matric'] as Map? ?? {};
        if (ma.isNotEmpty) {
          _matricState = ma['state']?.toString();
          _matricCity = ma['city']?.toString();
          _matricSchoolController.text = ma['schoolName']?.toString() ?? '';
          _matricYear = ma['passingYear']?.toString();
          _matricGradeController.text = ma['grade']?.toString() ?? '';
          _matricSavedTranscript = hasFile(ma['transcript']) ? ma['transcript'].toString() : null;
          _matricSavedCertificate = hasFile(ma['certificate']) ? ma['certificate'].toString() : null;
        }
      }
      localFiles.clear();
    });
  }

  @override
  void onDataSaved() => _loadData();

  @override
  void removeFile(String key) {
    setState(() {
      localFiles.remove(key);
      if (key == 'matricTranscript') _matricSavedTranscript = null;
      if (key == 'matricCertificate') _matricSavedCertificate = null;
    });
    msg('File removed. Tap Save to apply.', ok: false);
  }

  void _save() {
    saveSection(
      sectionEducation: {
        'matric': {
          'state': _matricState,
          'city': _matricCity,
          'schoolName': _matricSchoolController.text.trim(),
          'passingYear': _matricYear,
          'grade': _matricGradeController.text.trim(),
          'transcript': _matricSavedTranscript,
          'certificate': _matricSavedCertificate,
        },
      },
    );
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _matricSchoolController.dispose();
    _matricGradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eduSlate100,
      appBar: buildSectionAppBar('School (Matric)'),
      body: buildSectionBody([
        buildDrop(
          'State / Province',
          LocationData.getStates(EducationSectionMixin.defaultCountry),
          _matricState,
          (v) => setState(() { _matricState = v; _matricCity = null; }),
        ),
        if (_matricState != null && LocationData.getCities(EducationSectionMixin.defaultCountry, _matricState!).isNotEmpty)
          buildDrop(
            'City',
            LocationData.getCities(EducationSectionMixin.defaultCountry, _matricState!),
            _matricCity,
            (v) => setState(() => _matricCity = v),
          ),
        buildField('School Name', _matricSchoolController, Icons.school_outlined),
        buildYear('Passing Year', _matricYear, (v) => setState(() => _matricYear = v)),
        buildField('Grade/Percentage', _matricGradeController, Icons.percent_rounded),
        buildFp('Transcript', 'matricTranscript', _matricSavedTranscript),
        buildFp('Certificate', 'matricCertificate', _matricSavedCertificate),
        buildSaveBtn('Save Matric Info', _save),
      ]),
    );
  }
}
