import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../data/location_data.dart';
import '../widgets/education_widgets.dart';
import '../mixins/education_section_mixin.dart';

class EduBachelorScreen extends StatefulWidget {
  const EduBachelorScreen({super.key});
  @override
  State<EduBachelorScreen> createState() => _EduBachelorScreenState();
}

class _EduBachelorScreenState extends State<EduBachelorScreen>
    with EducationSectionMixin<EduBachelorScreen> {

  final _bachDegreeNameController        = TextEditingController();
  final _bachPreviousInstituteController = TextEditingController();
  String? _bachYear, _bachState, _bachCity;
  final _bachGradeController = TextEditingController();
  bool _bachIsAttested = false;
  String? _bachSavedTranscript, _bachSavedCertificate;

  StreamSubscription? _updateSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final edu = ApiService.currentUser?['education'];
    setState(() {
      _bachState = _bachCity = _bachYear = null;
      _bachDegreeNameController.text = '';
      _bachPreviousInstituteController.text = '';
      _bachGradeController.text = '';
      _bachIsAttested = false;
      _bachSavedTranscript = _bachSavedCertificate = null;

      if (edu != null) {
        final ba = edu['bachelor'] as Map? ?? {};
        if (ba.isNotEmpty) {
          _bachDegreeNameController.text = ba['degreeName']?.toString() ?? '';
          _bachPreviousInstituteController.text = (ba['collegeName'] ?? ba['instituteName'])?.toString() ?? '';
          _bachState = ba['state']?.toString();
          _bachCity = ba['city']?.toString();
          _bachYear = ba['passingYear']?.toString();
          _bachGradeController.text = ba['grade']?.toString() ?? '';
          _bachIsAttested = ba['isAttested'] == true;
          _bachSavedTranscript = hasFile(ba['transcript']) ? ba['transcript'].toString() : null;
          _bachSavedCertificate = hasFile(ba['certificate']) ? ba['certificate'].toString() : null;
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
      if (key == 'bachTranscript') _bachSavedTranscript = null;
      if (key == 'bachCertificate') _bachSavedCertificate = null;
    });
    msg('File removed. Tap Save to apply.', ok: false);
  }

  void _save() {
    saveSection(
      sectionEducation: {
        'bachelor': {
          'degreeName': _bachDegreeNameController.text.trim(),
          'collegeName': _bachPreviousInstituteController.text.trim(),
          'state': _bachState,
          'city': _bachCity,
          'passingYear': _bachYear,
          'grade': _bachGradeController.text.trim(),
          'transcript': _bachSavedTranscript,
          'certificate': _bachSavedCertificate,
          'isAttested': _bachIsAttested,
        },
      },
    );
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _bachDegreeNameController.dispose();
    _bachPreviousInstituteController.dispose();
    _bachGradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eduSlate100,
      appBar: buildSectionAppBar('Bachelor\'s'),
      body: buildSectionBody([
        buildField('Degree Name', _bachDegreeNameController, Icons.workspace_premium_outlined),
        buildField(
          'Previous University / Institute',
          _bachPreviousInstituteController,
          Icons.account_balance_outlined,
        ),
        buildDrop(
          'State / Province',
          LocationData.getStates(EducationSectionMixin.defaultCountry),
          _bachState,
          (v) => setState(() { _bachState = v; _bachCity = null; }),
        ),
        if (_bachState != null && LocationData.getCities(EducationSectionMixin.defaultCountry, _bachState!).isNotEmpty)
          buildDrop(
            'City',
            LocationData.getCities(EducationSectionMixin.defaultCountry, _bachState!),
            _bachCity,
            (v) => setState(() => _bachCity = v),
          ),
        buildYear('Passing Year', _bachYear, (v) => setState(() => _bachYear = v)),
        buildField('Grade/GPA', _bachGradeController, Icons.percent_rounded),
        buildToggle('HEC Attested?', _bachIsAttested, (v) => setState(() => _bachIsAttested = v)),
        buildFp('Transcript', 'bachTranscript', _bachSavedTranscript),
        buildFp('Degree Certificate', 'bachCertificate', _bachSavedCertificate),
        buildSaveBtn('Save Bachelor Info', _save),
      ]),
    );
  }
}
