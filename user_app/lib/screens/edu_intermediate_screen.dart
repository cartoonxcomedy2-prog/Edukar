import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/location_data.dart';
import '../widgets/education_widgets.dart';
import '../mixins/education_section_mixin.dart';

class EduIntermediateScreen extends StatefulWidget {
  const EduIntermediateScreen({super.key});
  @override
  State<EduIntermediateScreen> createState() => _EduIntermediateScreenState();
}

class _EduIntermediateScreenState extends State<EduIntermediateScreen>
    with EducationSectionMixin<EduIntermediateScreen> {

  String? _interYear, _interState, _interCity;
  final _interCollegeController = TextEditingController();
  final _interGradeController   = TextEditingController();
  String? _interSavedTranscript, _interSavedCertificate;

  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final edu = ApiService.currentUser?['education'];
    setState(() {
      _interState = _interCity = _interYear = null;
      _interCollegeController.text = '';
      _interGradeController.text = '';
      _interSavedTranscript = _interSavedCertificate = null;

      if (edu != null) {
        final ii = edu['intermediate'] as Map? ?? {};
        if (ii.isNotEmpty) {
          _interState = ii['state']?.toString();
          _interCity = ii['city']?.toString();
          _interCollegeController.text = ii['collegeName']?.toString() ?? '';
          _interYear = ii['passingYear']?.toString();
          _interGradeController.text = ii['grade']?.toString() ?? '';
          _interSavedTranscript = hasFile(ii['transcript']) ? ii['transcript'].toString() : null;
          _interSavedCertificate = hasFile(ii['certificate']) ? ii['certificate'].toString() : null;
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
      if (key == 'interTranscript') _interSavedTranscript = null;
      if (key == 'interCertificate') _interSavedCertificate = null;
    });
    msg('File removed. Tap Save to apply.', ok: false);
  }

  void _save() {
    saveSection(
      sectionEducation: {
        'intermediate': {
          'state': _interState,
          'city': _interCity,
          'collegeName': _interCollegeController.text.trim(),
          'passingYear': _interYear,
          'grade': _interGradeController.text.trim(),
          'transcript': _interSavedTranscript,
          'certificate': _interSavedCertificate,
        },
      },
    );
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _interCollegeController.dispose();
    _interGradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eduSlate100,
      appBar: buildSectionAppBar('College (Intermediate)'),
      body: buildSectionBody([
        buildDrop(
          'State / Province',
          LocationData.getStates(EducationSectionMixin.defaultCountry),
          _interState,
          (v) => setState(() { _interState = v; _interCity = null; }),
        ),
        if (_interState != null && LocationData.getCities(EducationSectionMixin.defaultCountry, _interState!).isNotEmpty)
          buildDrop(
            'City',
            LocationData.getCities(EducationSectionMixin.defaultCountry, _interState!),
            _interCity,
            (v) => setState(() => _interCity = v),
          ),
        buildField('College Name', _interCollegeController, Icons.account_balance_outlined),
        buildYear('Passing Year', _interYear, (v) => setState(() => _interYear = v)),
        buildField('Grade/Percentage', _interGradeController, Icons.percent_rounded),
        buildFp('Transcript', 'interTranscript', _interSavedTranscript),
        buildFp('Certificate', 'interCertificate', _interSavedCertificate),
        buildSaveBtn('Save Intermediate Info', _save),
      ]),
    );
  }
}
