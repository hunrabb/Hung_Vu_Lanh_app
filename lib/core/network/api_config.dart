import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String _detectedBaseUrl = defaultBaseUrl(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  static String get baseUrl =>
      _configuredBaseUrl.isNotEmpty ? _configuredBaseUrl : _detectedBaseUrl;

  static Future<void> initialize({
    bool? isWebOverride,
    TargetPlatform? platformOverride,
    Future<bool> Function()? androidPhysicalDeviceResolver,
  }) async {
    if (_configuredBaseUrl.isNotEmpty) return;

    final isWeb = isWebOverride ?? kIsWeb;
    final platform = platformOverride ?? defaultTargetPlatform;

    if (isWeb) {
      _detectedBaseUrl = 'http://localhost:3000/api';
      return;
    }

    if (platform == TargetPlatform.android) {
      final isPhysicalDevice =
          await (androidPhysicalDeviceResolver ?? _isPhysicalAndroidDevice)();
      _detectedBaseUrl = isPhysicalDevice
          ? 'http://localhost:3000/api'
          : 'http://10.0.2.2:3000/api';
      return;
    }

    _detectedBaseUrl = 'http://localhost:3000/api';
  }

  static Future<bool> _isPhysicalAndroidDevice() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.isPhysicalDevice;
  }

  static String defaultBaseUrl({
    required bool isWeb,
    required TargetPlatform platform,
  }) => !isWeb && platform == TargetPlatform.android
      ? 'http://10.0.2.2:3000/api'
      : 'http://localhost:3000/api';
}
