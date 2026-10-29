class NewsFeedArticle {
  const NewsFeedArticle({
    required this.title,
    required this.description,
    required this.link,
    this.imageUrl,
  });

  final String title;
  final String description;
  final String link;
  final String? imageUrl;
}

List<NewsFeedArticle> parseNewsFeedRss(String xml, {int limit = 5}) {
  final items = <NewsFeedArticle>[];
  final itemPattern = RegExp(r'<item\b[^>]*>(.*?)</item\s*>', dotAll: true);
  final titlePattern = RegExp(
    r'<title\b[^>]*>\s*(?:<!\[CDATA\[(.*?)\]\]>|(.*?))\s*</title\s*>',
    dotAll: true,
    caseSensitive: false,
  );
  final descriptionPattern = RegExp(
    r'<description\b[^>]*>\s*(?:<!\[CDATA\[(.*?)\]\]>|(.*?))\s*</description\s*>',
    dotAll: true,
    caseSensitive: false,
  );
  final linkPattern = RegExp(
    r'<link\b[^>]*>\s*(.*?)\s*</link\s*>',
    dotAll: true,
    caseSensitive: false,
  );

  for (final match in itemPattern.allMatches(xml)) {
    final item = match.group(1) ?? '';
    final titleMatch = titlePattern.firstMatch(item);
    final descriptionMatch = descriptionPattern.firstMatch(item);
    final linkMatch = linkPattern.firstMatch(item);
    final rawTitle = titleMatch?.group(1) ?? titleMatch?.group(2) ?? '';
    final rawDescription =
        descriptionMatch?.group(1) ?? descriptionMatch?.group(2) ?? '';
    final title = _plainText(rawTitle);
    if (title.isEmpty) continue;

    items.add(
      NewsFeedArticle(
        title: title,
        description: _plainText(rawDescription),
        link: _decodeXmlEntities(linkMatch?.group(1)?.trim() ?? ''),
        imageUrl: _findImageUrl(item),
      ),
    );
    if (items.length >= limit) break;
  }
  return items;
}

String? _findImageUrl(String item) {
  final patterns = [
    RegExp(
      r'<enclosure\b[^>]*\burl\s*=\s*["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
      dotAll: true,
    ),
    RegExp(
      r'<media:(?:content|thumbnail)\b[^>]*\burl\s*=\s*["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
      dotAll: true,
    ),
    RegExp(
      r'<img\b[^>]*\bsrc\s*=\s*["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
      dotAll: true,
    ),
  ];

  for (final pattern in patterns) {
    final candidate = pattern.firstMatch(item)?.group(1);
    if (candidate == null) continue;
    final url = _decodeXmlEntities(candidate.trim());
    final uri = Uri.tryParse(url);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return uri.toString();
    }
  }
  return null;
}

String _plainText(String value) => _decodeXmlEntities(
  value.replaceAll(RegExp(r'<[^>]*>'), ' '),
).replaceAll(RegExp(r'\s+'), ' ').trim();

String _decodeXmlEntities(String value) {
  const namedEntities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
  };
  var decoded = value;
  for (final entry in namedEntities.entries) {
    decoded = decoded.replaceAll(entry.key, entry.value);
  }
  return decoded.replaceAllMapped(
    RegExp(r'&#(?:x([0-9a-fA-F]+)|(\d+));'),
    (match) {
      final codePoint = int.tryParse(
        match.group(1) ?? match.group(2)!,
        radix: match.group(1) == null ? 10 : 16,
      );
      return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
    },
  );
}
