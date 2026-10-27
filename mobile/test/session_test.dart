import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/quote.dart';
import 'package:philoscroll/src/session.dart';

import 'support.dart';

class ThrowingStore implements ScrollStore {
  @override
  String? getItem(String key) => throw StateError('closed');

  @override
  void setItem(String key, String value) => throw StateError('full');
}

void main() {
  final quotes = loadTestQuotes();

  test('round-trips deck and browse position in storage', () {
    final storage = MemoryScrollStore();
    final pool = scrollPoolKey(quotes);
    saveScroll(
      StoredScroll(v: 1, pool: pool, queueIds: ['3', '2', '1'], lastId: '9', seenIds: ['9', '8'], index: 1),
      storage,
    );
    final loaded = loadScroll(pool, storage);
    expect(loaded?.queueIds, ['3', '2', '1']);
    expect(loaded?.lastId, '9');
    expect(loaded?.seenIds, ['9', '8']);
    expect(loaded?.index, 1);
    expect(loaded?.pool, pool);
  });

  test('drops saved state when the teaching list changes', () {
    final storage = MemoryScrollStore();
    final pool = scrollPoolKey(quotes);
    saveScroll(StoredScroll(v: 1, pool: pool, queueIds: ['1'], seenIds: ['1'], index: 0), storage);
    expect(loadScroll('$pool-other', storage), isNull);
  });

  test('ignores a broken saved place and a store that refuses the write', () {
    final storage = MemoryScrollStore();
    storage.setItem(scrollStorageKey, '{not json');
    expect(loadScroll('pool', storage), isNull);
    storage.setItem(
      scrollStorageKey,
      '{"v":1,"pool":"pool","queueIds":["1"],"seenIds":["1"],"index":4}',
    );
    expect(loadScroll('pool', storage), isNull);
    final throwing = ThrowingStore();
    expect(loadScroll('pool', throwing), isNull);
    expect(
      () => saveScroll(StoredScroll(v: 1, pool: 'pool', queueIds: ['1'], seenIds: ['1'], index: 0), throwing),
      returnsNormally,
    );
  });

  test('names a teaching list the same way the web scroll does', () {
    expect(
      scrollPoolKey(const [
        Quote(id: '1', text: 'a', author: 'b'),
        Quote(id: '2', text: 'c', author: 'd'),
        Quote(id: '10', text: 'e', author: 'f'),
      ]),
      '3:f6a6a3',
    );
  });
}
