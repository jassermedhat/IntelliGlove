import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'development_testing_session.dart';

typedef FirebaseTokenProvider = Future<String?> Function({bool forceRefresh});

class BackendApiException implements Exception {
  const BackendApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isServiceDisabled => code == 'SERVICE_DISABLED';

  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient({
    http.Client? client,
    FirebaseTokenProvider? tokenProvider,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? _firebaseToken,
       baseUrl = baseUrl ?? _configuredBaseUrl;

  static final instance = BackendApiClient();

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  final http.Client _client;
  final FirebaseTokenProvider _tokenProvider;
  final String baseUrl;

  // Caps every request so a down/unreachable backend surfaces as a handled
  // NETWORK_ERROR instead of an indefinite hang (infinite loading spinner).
  static const _requestTimeout = Duration(seconds: 15);

  static Future<String?> _firebaseToken({bool forceRefresh = false}) async {
    if (await DevelopmentTestingSession.isActive()) {
      return developmentTestingUserToken;
    }
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
  }

  Future<String?> authenticationToken({bool forceRefresh = false}) {
    return _tokenProvider(forceRefresh: forceRefresh);
  }

  Future<Object?> get(String path, {Map<String, String>? query}) {
    return _request('GET', path, query: query);
  }

  Future<Object?> post(String path, {Object? body}) {
    return _request('POST', path, body: body);
  }

  Future<Object?> patch(String path, {Object? body}) {
    return _request('PATCH', path, body: body);
  }

  Future<Object?> delete(String path) => _request('DELETE', path);

  Future<Object?> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool retried = false,
  }) async {
    final token = await _tokenProvider(forceRefresh: retried);
    if (token == null || token.isEmpty) {
      throw const BackendApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Authentication is required.',
      );
    }
    final root = Uri.parse('$baseUrl$path');
    final uri = query == null ? root : root.replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      response = await http.Response.fromStream(streamed).timeout(_requestTimeout);
    } on TimeoutException {
      throw const BackendApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'The server took too long to respond. Please try again later.',
      );
    } on Exception {
      throw const BackendApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Cannot reach the server. Check your connection.',
      );
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded['data'];
      return decoded;
    }
    final error = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    final code = error['code'] as String? ?? 'REQUEST_FAILED';
    if (!retried && response.statusCode == 401) {
      return _request(method, path, body: body, query: query, retried: true);
    }
    throw BackendApiException(
      statusCode: response.statusCode,
      code: code,
      message: error['message'] as String? ?? 'The request failed.',
      details: error['details'],
    );
  }

  void close() => _client.close();
}
