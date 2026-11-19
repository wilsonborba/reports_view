/// Builds open-in-Reports URLs from a caller-provided base URI and resource identifiers.
class ReportsLinkBuilder {
  final Uri baseUri;

  const ReportsLinkBuilder(this.baseUri);

  Uri reportUri({
    required String project,
    required String report,
    String? lang,
  }) {
    final segments = [
      ...baseUri.pathSegments.where((s) => s.isNotEmpty),
      'projects',
      project,
      'reports',
      report,
    ];
    return baseUri.replace(
      pathSegments: segments,
      queryParameters: lang == null || lang.isEmpty ? null : {'lang': lang},
    );
  }

  Uri cardUri({
    required String project,
    required String report,
    required String cardId,
    String? lang,
  }) {
    final segments = [
      ...baseUri.pathSegments.where((s) => s.isNotEmpty),
      'menu',
      project,
      report,
      cardId,
    ];
    return baseUri.replace(
      pathSegments: segments,
      queryParameters: lang == null || lang.isEmpty ? null : {'lang': lang},
    );
  }
}
