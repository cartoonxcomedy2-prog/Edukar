enum ApplicationProgramLevel { bachelor, master, phd }

class ApplicationDocumentGuard {
  static ApplicationProgramLevel resolveLevel(
    String? rawType, {
    String? fallbackName,
  }) {
    final raw = _clean(rawType);
    final name = _clean(fallbackName);
    final text = raw.isNotEmpty ? raw : name;

    if (text.contains('phd') ||
        text.contains('doctor') ||
        text.contains('doctoral') ||
        text.contains('doctorate')) {
      return ApplicationProgramLevel.phd;
    }

    if (text.contains('master') ||
        text.contains('ms') ||
        text.contains('msc') ||
        text.contains('mphil') ||
        text.contains('postgraduate')) {
      return ApplicationProgramLevel.master;
    }

    if (text.contains('bachelor') ||
        text.contains('bs') ||
        text.contains('ba') ||
        text.contains('bsc') ||
        text.contains('undergraduate') ||
        text.contains('ug') ||
        text.contains('llb')) {
      return ApplicationProgramLevel.bachelor;
    }

    return ApplicationProgramLevel.bachelor;
  }

  static String levelLabel(ApplicationProgramLevel level) {
    switch (level) {
      case ApplicationProgramLevel.bachelor:
        return 'Bachelor';
      case ApplicationProgramLevel.master:
        return 'Master';
      case ApplicationProgramLevel.phd:
        return 'PhD';
    }
  }

  static String buildMissingDocumentsMessage(
    ApplicationProgramLevel level,
    List<String> missingDocuments,
  ) {
    final docs = missingDocuments.join(', ');
    return 'Please upload the missing documents for ${levelLabel(level)}: $docs.';
  }

  static List<String> missingDocumentsForLevel({
    required Map<String, dynamic>? user,
    required ApplicationProgramLevel level,
  }) {
    final education = _asMap(user?['education']);
    final missing = <String>[];

    if (!_hasPersonalInfo(education)) {
      missing.add('Personal Information');
    }

    if (!_hasIdentityDocument(education)) {
      missing.add('Identity Documents');
    }

    if (level == ApplicationProgramLevel.bachelor ||
        level == ApplicationProgramLevel.master ||
        level == ApplicationProgramLevel.phd) {
      if (!_hasAcademicData(education, 'matric')) {
        missing.add('Matric Documents & Details');
      }
      if (!_hasAcademicData(education, 'intermediate')) {
        missing.add('Intermediate Documents & Details');
      }
    }

    if (level == ApplicationProgramLevel.master ||
        level == ApplicationProgramLevel.phd) {
      if (!_hasAcademicData(education, 'bachelor')) {
        missing.add('Bachelor Documents & Details');
      }
    }

    if (level == ApplicationProgramLevel.phd) {
      if (!_hasAcademicData(education, 'masters')) {
        missing.add('Master Documents & Details');
      }
    }

    return missing;
  }

  static bool _hasPersonalInfo(Map<String, dynamic>? education) {
    final personal = _asMap(education?['personalInfo']);
    return _hasValue(personal?['fatherName']) &&
        _hasValue(personal?['fatherContactNumber']) &&
        _hasValue(personal?['dateOfBirth']);
  }

  static bool _hasIdentityDocument(Map<String, dynamic>? education) {
    final nationalId = _asMap(education?['nationalId']);
    return _hasValue(nationalId?['file']);
  }

  static bool _hasAcademicData(
    Map<String, dynamic>? education,
    String sectionKey,
  ) {
    final section = _asMap(education?[sectionKey]);
    final hasDoc = _hasValue(section?['transcript']) ||
        _hasValue(section?['certificate']);

    final hasInst = _hasValue(section?['schoolName']) ||
        _hasValue(section?['collegeName']) ||
        _hasValue(section?['instituteName']);

    final hasYear = _hasValue(section?['passingYear']);
    final hasGrade = _hasValue(section?['grade']);

    bool hasDegree = true;
    if (sectionKey == 'bachelor' || sectionKey == 'masters' || sectionKey == 'phd') {
      hasDegree = _hasValue(section?['degreeName']);
    }

    return hasDoc && hasInst && hasYear && hasGrade && hasDegree;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    return value.toString().trim().isNotEmpty;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _clean(String? value) {
    return (value ?? '').toLowerCase().trim();
  }
}
