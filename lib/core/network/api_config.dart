import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static String get baseUrl =>
      const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : defaultBaseUrl(isWeb: kIsWeb, platform: defaultTargetPlatform);
  static String defaultBaseUrl({
    required bool isWeb,
    required TargetPlatform platform,
  }) => !isWeb && platform == TargetPlatform.android
      ? 'http://10.0.2.2:3000/api'
      : 'http://localhost:3000/api';
}
