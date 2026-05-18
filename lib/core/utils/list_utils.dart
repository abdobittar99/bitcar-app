List<List<T>> chunkList<T>(List<T> list, int size) {
  final chunks = <List<T>>[];
  for (var i = 0; i < list.length; i += size) {
    chunks.add(
      list.sublist(i, i + size > list.length ? list.length : i + size),
    );
  }
  return chunks;
}
