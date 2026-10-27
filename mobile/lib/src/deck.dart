import 'dart:math' as math;

import 'quote.dart';

List<T> shuffle<T>(List<T> items, double Function() random) {
  final copy = List<T>.from(items);
  for (var i = copy.length - 1; i > 0; i -= 1) {
    final j = math.min(i, (random() * (i + 1)).floor());
    final current = copy[i];
    copy[i] = copy[j];
    copy[j] = current;
  }
  return copy;
}

class DeckResume {
  const DeckResume({required this.queue, this.lastId});

  final List<Quote> queue;
  final String? lastId;
}

class DeckSnapshot {
  const DeckSnapshot({required this.queueIds, this.lastId});

  final List<String> queueIds;
  final String? lastId;
}

class QuoteDeck {
  QuoteDeck(this.pool, [double Function()? random, DeckResume? resume])
    : _random = random ?? math.Random().nextDouble {
    if (resume != null) {
      _queue = List<Quote>.from(resume.queue);
      _lastId = resume.lastId;
    } else if (pool.isNotEmpty) {
      _refill(null);
    }
  }

  final List<Quote> pool;
  final double Function() _random;
  List<Quote> _queue = [];
  String? _lastId;

  DeckSnapshot snapshot() {
    return DeckSnapshot(queueIds: _queue.map((quote) => quote.id).toList(), lastId: _lastId);
  }

  Quote? draw() {
    if (pool.isEmpty) return null;
    if (_queue.isEmpty) _refill(_lastId);
    if (_queue.isEmpty) return null;
    final quote = _queue.removeAt(0);
    _lastId = quote.id;
    return quote;
  }

  void _refill(String? avoidId) {
    final next = shuffle(pool, _random);
    if (avoidId != null && next.length > 1 && next.first.id == avoidId) {
      final first = next.removeAt(0);
      next.add(first);
    }
    _queue = next;
  }
}

QuoteDeck? resumeDeck(
  List<Quote> pool,
  double Function() random,
  List<String> queueIds, {
  String? lastId,
}) {
  final byId = {for (final quote in pool) quote.id: quote};
  final queue = <Quote>[];
  for (final id in queueIds) {
    final quote = byId[id];
    if (quote == null) return null;
    queue.add(quote);
  }
  return QuoteDeck(pool, random, DeckResume(queue: queue, lastId: lastId));
}
