import 'dart:convert';

import 'quote.dart';

const scrollStorageKey = 'philoscroll-scroll';

abstract class ScrollStore {
  String? getItem(String key);
  void setItem(String key, String value);
}

class MemoryScrollStore implements ScrollStore {
  final Map<String, String> data = {};

  @override
  String? getItem(String key) => data[key];

  @override
  void setItem(String key, String value) {
    data[key] = value;
  }
}

class StoredScroll {
  const StoredScroll({
    required this.v,
    required this.pool,
    required this.queueIds,
    required this.seenIds,
    required this.index,
    this.lastId,
  });

  final int v;
  final String pool;
  final List<String> queueIds;
  final String? lastId;
  final List<String> seenIds;
  final int index;

  Map<String, Object> toJson() {
    return {
      'v': v,
      'pool': pool,
      'queueIds': queueIds,
      'seenIds': seenIds,
      'index': index,
      'lastId': ?lastId,
    };
  }
}

/// FNV-1a over the sorted ids, kept identical to the web scroll so a changed
/// teaching list invalidates a saved place.
String scrollPoolKey(List<Quote> quotes) {
  var hash = 2166136261;
  final ids = quotes.map((quote) => quote.id).toList()..sort();
  for (final id in ids) {
    for (final unit in id.codeUnits) {
      hash = _jsInt32(hash) ^ unit;
      hash = _imul(hash, 16777619);
    }
    hash = _jsInt32(hash) ^ 10;
    hash = _imul(hash, 16777619);
  }
  return '${quotes.length}:${(hash & 0xFFFFFFFF).toRadixString(36)}';
}

StoredScroll? loadScroll(String pool, ScrollStore? storage) {
  if (storage == null) return null;
  try {
    final raw = storage.getItem(scrollStorageKey);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    if (data['v'] != 1 || data['pool'] != pool) return null;
    final queueIds = data['queueIds'];
    final seenIds = data['seenIds'];
    if (queueIds is! List || seenIds is! List) return null;
    if (!queueIds.every((id) => id is String)) return null;
    if (!seenIds.every((id) => id is String)) return null;
    final index = data['index'];
    if (index is! int || index < 0 || index >= seenIds.length) return null;
    final lastId = data['lastId'];
    if (lastId != null && lastId is! String) return null;
    return StoredScroll(
      v: 1,
      pool: pool,
      queueIds: queueIds.cast<String>().toList(),
      lastId: lastId as String?,
      seenIds: seenIds.cast<String>().toList(),
      index: index,
    );
  } catch (_) {
    return null;
  }
}

void saveScroll(StoredScroll state, ScrollStore? storage) {
  if (storage == null) return;
  try {
    storage.setItem(scrollStorageKey, jsonEncode(state.toJson()));
  } catch (_) {
    // Private mode or a full disk: keep scrolling without a saved place.
  }
}

List<Quote>? quotesFromIds(List<Quote> quotes, List<String> ids) {
  final byId = {for (final quote in quotes) quote.id: quote};
  final resolved = <Quote>[];
  for (final id in ids) {
    final quote = byId[id];
    if (quote == null) return null;
    resolved.add(quote);
  }
  return resolved;
}

int _jsInt32(int value) {
  final bits = value & 0xFFFFFFFF;
  return bits >= 0x80000000 ? bits - 0x100000000 : bits;
}

int _imul(int a, int b) => _jsInt32(_jsInt32(a) * _jsInt32(b));
