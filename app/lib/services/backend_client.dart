/// HTTP client for the Atelier backend. Bytes of the user's photo travel in
/// the request body only — the app never writes them to disk (BUILD_PLAN §5).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/analysis.dart';
import '../models/recommendation.dart';
import '../models/search.dart';
import '../models/size.dart';
import '../models/tryon.dart';

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
        payload: body,
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
        payload: body,
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
        payload: body,
      );
    }
    return outcome.toFailure();
  }

  /// Phase 4: person photo + garment photo → labeled render or §12 state.
  /// The hosted provider polls internally, hence the generous timeout.
  Future<TryOnOutcome> renderTryOn(Uint8List person, Uint8List garment) async {
    if (!isConfigured) {
      return const TryOnFailure(
        code: 'NETWORK_ERROR',
        message: 'No backend is configured. Set BACKEND_URL when building the app.',
      );
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/tryon/render'),
    )
      ..files.add(
        http.MultipartFile.fromBytes('person', person, filename: 'person.jpg'),
      )
      ..files.add(
        http.MultipartFile.fromBytes('garment', garment, filename: 'garment.jpg'),
      );
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 90));
      final resp = await http.Response.fromStream(streamed);
      final decoded = json.decode(resp.body);
      if (resp.statusCode == 200) {
        final body = decoded as Map<String, dynamic>;
        final render = body['render'] as Map<String, dynamic>;
        return TryOnOk(
          TryOnSuccess(
            render: TryOnRender(
              imageBytes: base64Decode(render['image'] as String),
              method: render['method'] as String,
              provider: render['provider'] as String,
            ),
            confidence: (body['confidence'] as num).toDouble(),
            flags: (body['flags'] as List<dynamic>).cast<String>(),
            category:
                (body['garment'] as Map<String, dynamic>)['category'] as String,
          ),
        );
      }
      final error = (decoded as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) {
        return TryOnFailure(
          code: error['code'] as String,
          message: error['message'] as String,
        );
      }
      return TryOnFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend rejected the request (${resp.statusCode}).',
      );
    } on FormatException {
      return const TryOnFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend returned an unreadable response.',
      );
    } catch (_) {
      return const TryOnFailure(
        code: 'NETWORK_ERROR',
        message: 'Could not reach the try-on service. Check the connection and try again.',
      );
    }
  }

  /// Phase 5: real body profile + real user-entered size chart → size.
  Future<SizeOutcome> recommendSize({
    required String category,
    required String fitType,
    required Map<String, dynamic> bodyProfile,
    required List<Map<String, dynamic>> rows,
    String brand = '',
  }) async {
    if (!isConfigured) {
      return const SizeFailure(
        code: 'NETWORK_ERROR',
        message: 'No backend is configured. Set BACKEND_URL when building the app.',
      );
    }
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/size/recommend'),
            headers: {'content-type': 'application/json'},
            body: json.encode({
              'category': category,
              'fit_type': fitType,
              'body_profile': bodyProfile,
              'size_chart': {'brand': brand, 'rows': rows},
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = json.decode(resp.body);
      if (resp.statusCode == 200) {
        return SizeOk(
          SizeRecommendation.fromJson(decoded as Map<String, dynamic>),
        );
      }
      final error = (decoded as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) {
        return SizeFailure(
          code: error['code'] as String,
          message: error['message'] as String,
        );
      }
      return SizeFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend rejected the request (${resp.statusCode}).',
      );
    } on FormatException {
      return const SizeFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend returned an unreadable response.',
      );
    } catch (_) {
      return const SizeFailure(
        code: 'NETWORK_ERROR',
        message: 'Could not reach the size engine. Check the connection and try again.',
      );
    }
  }

  /// Phase 8: query photo + the wardrobe's real embeddings → tiered matches
  /// or NO_MATCH_FOUND. The index lives where the real data lives.
  Future<SearchOutcome> searchSimilar(
    Uint8List query,
    List<Map<String, dynamic>> candidates,
  ) async {
    if (!isConfigured) {
      return const SearchFailure(
        code: 'NETWORK_ERROR',
        message: 'No backend is configured. Set BACKEND_URL when building the app.',
      );
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/search/similar'),
    )
      ..files.add(
        http.MultipartFile.fromBytes('file', query, filename: 'query.jpg'),
      )
      ..fields['candidates'] = json.encode(candidates);
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamed);
      final decoded = json.decode(resp.body);
      if (resp.statusCode == 200) {
        return SearchOk(
          SimilarSearchResult.fromJson(decoded as Map<String, dynamic>),
        );
      }
      final error = (decoded as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) {
        return SearchFailure(
          code: error['code'] as String,
          message: error['message'] as String,
        );
      }
      return SearchFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend rejected the request (${resp.statusCode}).',
      );
    } on FormatException {
      return const SearchFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend returned an unreadable response.',
      );
    } catch (_) {
      return const SearchFailure(
        code: 'NETWORK_ERROR',
        message: 'Could not reach the search service. Check the connection and try again.',
      );
    }
  }

  /// Phase 3: score outfits from the user's real wardrobe + profiles.
  /// First JSON POST in the codebase; the backend fetches real weather
  /// inside this call, hence the generous timeout.
  Future<RecommendOutcome> recommendOutfit({
    required String occasion,
    required double latitude,
    required double longitude,
    required String placeLabel,
    required Map<String, dynamic> bodyProfile,
    Map<String, dynamic>? colorProfile,
    required Map<String, dynamic> styleProfile,
    required List<Map<String, dynamic>> wardrobe,
  }) async {
    if (!isConfigured) {
      return const RecommendFailure(
        code: 'NETWORK_ERROR',
        message: 'No backend is configured. Set BACKEND_URL when building the app.',
      );
    }
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/recommend/outfit'),
            headers: {'content-type': 'application/json'},
            body: json.encode({
              'occasion': occasion,
              'location': {
                'latitude': latitude,
                'longitude': longitude,
                'label': placeLabel,
              },
              'body_profile': bodyProfile,
              'color_profile': colorProfile,
              'style_profile': styleProfile,
              'wardrobe': wardrobe,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final decoded = json.decode(resp.body);
      if (resp.statusCode == 200) {
        return RecommendSuccess(
            OutfitRecommendation.fromJson(decoded as Map<String, dynamic>));
      }
      final error = (decoded as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic>) {
        return RecommendFailure(
          code: error['code'] as String,
          message: error['message'] as String,
        );
      }
      return RecommendFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend rejected the request (${resp.statusCode}).',
      );
    } on FormatException {
      return const RecommendFailure(
        code: 'NETWORK_ERROR',
        message: 'The backend returned an unreadable response.',
      );
    } catch (_) {
      return const RecommendFailure(
        code: 'NETWORK_ERROR',
        message: 'Could not reach the recommendation service. Check the connection and try again.',
      );
    }
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
