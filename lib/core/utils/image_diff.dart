class ImageDiff {
  final List<String> added;
  final List<String> removed;
  final bool reordered;
  final bool replaced;

  const ImageDiff({
    required this.added,
    required this.removed,
    required this.reordered,
    required this.replaced,
  });

  bool get hasChanges =>
      added.isNotEmpty || removed.isNotEmpty || reordered || replaced;
}

ImageDiff calculateImageChanges(List<String> oldList, List<String> newList) {
  final oldSet = oldList.toSet();
  final newSet = newList.toSet();

  final added = newSet.difference(oldSet).toList();
  final removed = oldSet.difference(newSet).toList();

  final sameItems =
      oldSet.length == newSet.length && oldSet.containsAll(newSet);

  final reordered = sameItems && !_listEquals(oldList, newList);

  final replaced = !sameItems && added.isNotEmpty && removed.isNotEmpty;

  return ImageDiff(
    added: added,
    removed: removed,
    reordered: reordered,
    replaced: replaced,
  );
}

bool _listEquals(List a, List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
