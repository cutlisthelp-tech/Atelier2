/// Typed Phase 8 Find-This-Look results.
library;

class SimilarMatch {
  const SimilarMatch({
    required this.id,
    required this.similarity,
    required this.tier,
  });

  final String id;
  final double similarity;

  /// exact_match | close_match | inspired.
  final String tier;

  factory SimilarMatch.fromJson(Map<String, dynamic> json) => SimilarMatch(
        id: json['id'] as String,
        similarity: (json['similarity'] as num).toDouble(),
        tier: json['tier'] as String,
      );
}

class SimilarSearchResult {
  const SimilarSearchResult({
    required this.state,
    required this.matches,
    required this.index,
    required this.method,
    required this.catalogNote,
    required this.message,
  });

  /// "ok" or "NO_MATCH_FOUND".
  final String state;
  final List<SimilarMatch> matches;
  final String index;
  final String method;
  final String catalogNote;
  final String message;

  factory SimilarSearchResult.fromJson(Map<String, dynamic> json) =>
      SimilarSearchResult(
        state: json['state'] as String,
        matches: (json['matches'] as List<dynamic>)
            .map((m) => SimilarMatch.fromJson(m as Map<String, dynamic>))
            .toList(),
        index: json['index'] as String,
        method: json['method'] as String,
        catalogNote:
            (json['catalog'] as Map<String, dynamic>)['note'] as String,
        message: json['message'] as String,
      );
}

sealed class SearchOutcome {
  const SearchOutcome();
}

class SearchOk extends SearchOutcome {
  const SearchOk(this.result);
  final SimilarSearchResult result;
}

class SearchFailure extends SearchOutcome {
  const SearchFailure({required this.code, required this.message});

  /// A §12 failure-state code, e.g. POOR_IMAGE, INSUFFICIENT_DATA.
  final String code;
  final String message;
}
