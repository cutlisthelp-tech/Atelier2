/// HTTP client for the Atelier backend. Bytes of the user's photo travel in
/// the request body only — the app never writes them to disk (BUILD_PLAN §5).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/analysis.dart';

class BackendClient {
  BackendClient({
    this.baseUrl = const String.fromEnvironment('BACKEND_URL'),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<ScanOutcome> analyzeBody(Uint8List image, double heightCm) async {
    final outcome = await _post(
      '/analysis/body',
      image,
      fields: {'height_cm': heightCm.toString()},
    );
    if (outcome case _Success(:final body)) {
      return BodyScanSuccess(
        body: BodyProfile.fromJson(body['body'] as Map<String, dynamic>),
        confidence: (body['confidence'] as num).toDouble(),
        flags: (body['flags'] as List<dynamic>).cast<String>(),
      );
    }
    return outcome.toFailure();
  }

  Future<ScanOutcome> analyzeAppearance(Uint8List image) async {
    final outcome = await _post('/analysis/appearance', image);
    if (outcome case _Success(:final body)) {
      return AppearanceScanSuccess(
        color: ColorProfile.fromJson(body['color'] as Map<String, dynamic>),
        confidence: (body['confidence'] as num).toDouble(),
        flags: (body['flags'] as List<dynamic>).cast<String>(),
      );
    }
    return outcome.toFailure();
  }

  Future<ScanOutcome> analyzeGarment(Uint8List image) async {
    final outcome = await _post('/analysis/garment', image);
    if (outcome case _Success(:final body)) {
      return GarmentScanSuccess(
        garment:
            GarmentProfile.fromJson(body['garment'] as Map<String, dynamic>),
        confidence: (body['confidence'] as num).toDouble(),
        flags: (body['flags'] as List<dynamic>).cast<String>(),
      );
    }
    return outcome.toFailure();
  }

  Future<List<ModelStatus>> fetchModels() async {
    final uri = Uri.parse('$baseUrl/models');
    final resp = await _http.get(uri, headers: {'accept': 'application/json'});
    if (resp.statusCode != 200) {
      throw StateError('GET /models returned ${resp.statusCode}');
    }
    final list =
        (json.decode(resp.body) as Map<String, dynamic>)['models'] as List<dynamic>;
    return list
        .map((m) => ModelStatus.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<_Raw> _post(
    String path,
    Uint8List image, {
    Map<String, String> fields = const {},
  }) async {
    if (!isConfigured) {
      return const _NetworkFailure(
        'No backend is configured. Set BACKEND_URL when building the app.',
      );
    }
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('file', image, filename: 'scan.jpg'));
    try {
      final streamed = await _http.send(request);
      final resp = await http.Response.fromStream(streamed);
      final decoded = json.decode(resp.body);
      if (resp.statusCode == 200) {
        return _Success(decoded as Map<String, dynamic>);
      }
      final error = (decoded as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) {
        return _ApiFailure(
          code: error['code'] as String,
          message: error['message'] as String,
        );
      }
      return _NetworkFailure('The backend rejected the request (${resp.statusCode}).');
    } on FormatException {
      return const _NetworkFailure('The backend returned an unreadable response.');
    } catch (_) {
      return const _NetworkFailure(
        'Could not reach the analysis service. Check the connection and try again.',
      );
    }
  }
}

sealed class _Raw {
  const _Raw();

  ScanOutcome toFailure() => switch (this) {
        _Success() => throw StateError('not a failure'),
        _ApiFailure(:final code, :final message) =>
          ScanFailure(code: code, message: message),
        _NetworkFailure(:final message) =>
          ScanFailure(code: 'NETWORK_ERROR', message: message),
      };
}

class _Success extends _Raw {
  const _Success(this.body);
  final Map<String, dynamic> body;
}

class _ApiFailure extends _Raw {
  const _ApiFailure({required this.code, required this.message});
  final String code;
  final String message;
}

class _NetworkFailure extends _Raw {
  const _NetworkFailure(this.message);
  final String message;
}
