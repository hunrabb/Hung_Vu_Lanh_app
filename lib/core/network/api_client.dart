import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'token_store.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.tokens, http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl {
    if (kDebugMode) {
      final uri = Uri.parse(this.baseUrl);
      debugPrint(
        'KTGK API: ${uri.scheme}://${uri.host}:${uri.port}${uri.path}',
      );
    }
  }
  final TokenStore tokens;
  final http.Client _client;
  final String baseUrl;
  void Function()? onUnauthorized;
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    String? tokenOverride,
  }) async {
    final revision = tokens.revision;
    final token = tokenOverride ?? (authenticated ? await tokens.read() : null);
    if (authenticated && revision != tokens.revision) {
      throw const ApiException(401, 'Phiên đăng nhập đã thay đổi.');
    }
    final request = http.Request(
      method,
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}/$path'),
    );
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 401 &&
          authenticated &&
          revision == tokens.revision) {
        onUnauthorized?.call();
      }
      dynamic data;
      if (response.bodyBytes.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } on FormatException {
          throw const ApiException(0, 'Phản hồi máy chủ không hợp lệ.');
        }
      }
      if (response.statusCode >= 400) {
        final message = data is Map ? data['message'] : null;
        throw ApiException(
          response.statusCode,
          message is String
              ? message
              : message is List
              ? message.join('\n')
              : 'Không thể xử lý yêu cầu.',
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException(0, 'Kết nối quá thời gian. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiException(
        0,
        'Không kết nối được máy chủ. Kiểm tra kết nối và địa chỉ API.',
      );
    }
  }

  void close() {
    onUnauthorized = null;
    _client.close();
  }
}
