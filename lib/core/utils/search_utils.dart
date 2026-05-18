String stripVowels(String word) {
  final vowels = RegExp(r'[aeiouy]');

  final vowelCount = vowels.allMatches(word).length;

  if (vowelCount <= 1) {
    return word;
  }

  return word.replaceAll(vowels, '');
}

List<String> generateSearchKeywords({
  required String brand,
  required String model,
  required int year,
  required String location,
}) {
  final raw = '$model $brand $year $location'.toLowerCase();

  final sanitized = raw.replaceAll(RegExp(r'[^\w\s]'), '');

  final parts = sanitized.split(RegExp(r'\s+'));

  final processed = parts
      .where((e) => e.isNotEmpty)
      .map((word) => stripVowels(word))
      .toSet()
      .toList();

  return processed;
}

List<String> normalizeSearchQuery(String input) {
  final raw = input.toLowerCase();

  final sanitized = raw.replaceAll(RegExp(r'[^\w\s]'), '');

  final parts = sanitized.split(RegExp(r'\s+'));

  final keywords = parts
      .where((e) => e.isNotEmpty)
      .map((word) => stripVowels(word))
      .toList();

  return keywords;
}
