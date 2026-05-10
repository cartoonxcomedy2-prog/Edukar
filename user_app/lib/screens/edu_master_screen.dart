import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/location_data.dart';
import '../widgets/education_widgets.dart';
import '../mixins/education_section_mixin.dart';

class EduMasterScreen extends StatefulWidget {
  const EduMasterScreen({super.key});
  @override
  State<EduMasterScreen> createState() => _EduMasterScreenState();
}

class _EduMasterScreenState extends State<EduMasterScreen>
    with EducationSectionMixin<EduMasterScreen> {

  final _masterDegreeNameController        = TextEditingController();
  final _masterPreviousInstituteController = TextEditingController();
  String? _masterYear, _masterState, _masterCity;
  final _masterGradeController = TextEditingController();
  bool _masterIsAttested = false;
  String? _masterSavedTranscript, _masterSavedCertificate;

  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final edu = ApiService.currentUser?['education'];
    setState(() {
      _masterState = _masterCity = _masterYear = null;
      _masterDegreeNameController.text = '';
      _masterPreviousInstituteController.text = '';
      _masterGradeController.text = '';
      _masterIsAttested = false;
      _masterSavedTranscript = _masterSavedCertificate = null;

      if (edu != null) {
        final ms = edu['masters'] as Map? ?? {};
        if (ms.isNotEmpty) {
          _masterDegreeNameController.text = ms['degreeName']?.toString() ?? '';
          _masterPreviousInstituteController.text = (ms['collegeName'] ?? ms['instituteName'])?.toString() ?? '';
          _masterState = ms['state']?.toString();
          _masterCity = ms['city']?.toString();
          _masterYear = ms['passingYear']?.toString();
          _masterGradeController.text = ms['grade']?.toString() ?? '';
          _masterIsAttested = ms['isAttested'] == true;
          _masterSavedTranscript = hasFile(ms['transcript']) ? ms['transcript'].toString() : null;
          _masterSavedCertificate = hasFile(ms['certificate']) ? ms['certificate'].toString() : null;
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
      if (key == 'masterTranscript') _masterSavedTranscript = null;
      if (key == 'masterCertificate') _masterSavedCertificate = null;
    });
    msg('File removed. Tap Save to apply.', ok: false);
  }

  void _save() {
    saveSection(
      sectionEducation: {
        'masters': {
          'degreeName': _masterDegreeNameController.text.trim(),
          'collegeName': _masterPreviousInstituteController.text.trim(),
          'state': _masterState,
          'city': _masterCity,
          'passingYear': _masterYear,
          'grade': _masterGradeController.text.trim(),
          'transcript': _masterSavedTranscript,
          'certificate': _masterSavedCertificate,
          'isAttested': _masterIsAttested,
        },
      },
    );
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _masterDegreeNameController.dispose();
    _masterPreviousInstituteController.dispose();
    _masterGradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eduSlate100,
      appBar: buildSectionAppBar('Master\'s'),
      body: buildSectionBody([
        buildField('Degree Name', _masterDegreeNameController, Icons.workspace_premium_outlined),
        buildField(
          'Previous University / Institute',
          _masterPreviousInstituteController,
          Icons.account_balance_outlined,
        ),
        buildDrop(
          'State / Province',
          LocationData.getStates(EducationSectionMixin.defaultCountry),
          _masterState,
          (v) => setState(() { _masterState = v; _masterCity = null; }),
        ),
        if (_masterState != null && LocationData.getCities(EducationSectionMixin.defaultCountry, _masterState!).isNotEmpty)
          buildDrop(
            'City',
            LocationData.getCities(EducationSectionMixin.defaultCountry, _masterState!),
            _masterCity,
            (v) => setState(() => _masterCity = v),
          ),
        buildYear('Passing Year', _masterYear, (v) => setState(() => _masterYear = v)),
        buildField('Grade/GPA', _masterGradeController, Icons.percent_rounded),
        buildToggle('HEC Attested?', _masterIsAttested, (v) => setState(() => _masterIsAttested = v)),
        buildFp('Transcript', 'masterTranscript', _masterSavedTranscript),
        buildFp('Degree Certificate', 'masterCertificate', _masterSavedCertificate),
        buildSaveBtn('Save Masters Info', _save),
      ]),
    );
  }
}
