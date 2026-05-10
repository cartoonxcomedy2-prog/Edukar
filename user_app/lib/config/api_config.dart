import 'package:flutter/foundation.dart';

class ApiConfig {
  static const int port = 5000;
  static const String _defaultLanBaseUrl =
      'https://supadmin.edukar.info/api/';
  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final raw = _baseUrlFromEnv.trim().isNotEmpty
        ? _baseUrlFromEnv
        : _defaultLanBaseUrl;
    return normalizeBaseUrl(raw);
  }

  static List<String> get candidateBaseUrls {
    final values = <String>[baseUrl, _defaultLanBaseUrl];

    if (kDebugMode) {
      values.addAll([
        'http://127.0.0.1:$port/api/',
        'http://localhost:$port/api/',
        'http://10.0.2.2:$port/api/', // Android emulator (AVD)
        'http://10.0.3.2:$port/api/', // Genymotion
      ]);
    }

    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final url = normalizeBaseUrl(value);
      if (seen.add(url)) {
        normalized.add(url);
      }
    }
    return normalized;
  }

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return _defaultLanBaseUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    if (!url.endsWith('/api')) {
      if (url.contains('/api')) {
        url = url.replaceAll(RegExp(r'/api.*$'), '/api');
      } else {
        url = '$url/api';
      }
    }
    return '$url/';
  }
}
