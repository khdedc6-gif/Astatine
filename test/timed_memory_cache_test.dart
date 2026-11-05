import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/cache/timed_memory_cache.dart';

void main() {
  test('copies nested values so callers cannot mutate cached state', () {
    final cache = TimedMemoryCache(ttl: const Duration(minutes: 1));
    cache.write('class', {
      'members': [
        {'name': 'A'},
      ],
    });

    final firstRead = cache.read('class') as Map<String, dynamic>;
    (firstRead['members'] as List).first['name'] = 'Changed';

    final secondRead = cache.read('class') as Map<String, dynamic>;
    expect(((secondRead['members'] as List).first as Map)['name'], 'A');
  });

  test('expires entries but permits a bounded stale-while-revalidate read', () {
    var now = DateTime(2026, 11, 5);
    final cache = TimedMemoryCache(
      ttl: const Duration(minutes: 1),
      clock: () => now,
    );
    cache.write('role', 'teacher');
    cache.write('expired', 'value');

    now = now.add(const Duration(minutes: 1));
    expect(cache.read('expired'), isNull);
    expect(
      cache.read(
        'role',
        allowExpired: true,
        staleFor: const Duration(seconds: 30),
      ),
      'teacher',
    );

    now = now.add(const Duration(seconds: 30));
    expect(
      cache.read(
        'role',
        allowExpired: true,
        staleFor: const Duration(seconds: 30),
      ),
      isNull,
    );
  });

  test('evicts the oldest entry when the cache reaches its size limit', () {
    final cache = TimedMemoryCache(
      ttl: const Duration(minutes: 1),
      maxEntries: 2,
    );
    cache
      ..write('first', 1)
      ..write('second', 2)
      ..write('third', 3);

    expect(cache.read('first'), isNull);
    expect(cache.read('second'), 2);
    expect(cache.read('third'), 3);
  });
}
