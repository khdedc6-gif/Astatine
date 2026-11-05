class TimedMemoryCache {
  TimedMemoryCache({
    required this.ttl,
    this.maxEntries = 32,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _clock;
  final Map<String, _CacheEntry> _entries = {};

  Object? read(
    String key, {
    bool allowExpired = false,
    Duration staleFor = Duration.zero,
  }) {
    final entry = _entries[key];
    if (entry == null) return null;
    final now = _clock();
    if (!now.isBefore(entry.expiresAt)) {
      final staleUntil = entry.expiresAt.add(staleFor);
      if (!allowExpired || !now.isBefore(staleUntil)) {
        _entries.remove(key);
        return null;
      }
    }

    return _copyValue(entry.value);
  }

  void write(String key, Object? value) {
    _entries.remove(key);
    _entries[key] = _CacheEntry(
      value: _copyValue(value),
      expiresAt: _clock().add(ttl),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void invalidate(String key) => _entries.remove(key);

  void invalidateWhere(bool Function(String key) predicate) {
    _entries.removeWhere((key, _) => predicate(key));
  }

  static Object? _copyValue(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _copyValue(entry.value),
      };
    }
    if (value is List) {
      return value.map(_copyValue).toList();
    }
    return value;
  }
}

class _CacheEntry {
  const _CacheEntry({required this.value, required this.expiresAt});

  final Object? value;
  final DateTime expiresAt;
}
