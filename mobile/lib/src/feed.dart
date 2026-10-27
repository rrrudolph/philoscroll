import 'dart:math' as math;

import 'deck.dart';
import 'quote.dart';
import 'session.dart';

class TeachingFeed {
  TeachingFeed({required List<Quote> quotes, double Function()? random, StoredScroll? stored})
    : quotes = List<Quote>.unmodifiable(quotes),
      _random = random ?? math.Random().nextDouble {
    final restored = stored == null ? null : quotesFromIds(this.quotes, stored.seenIds);
    final resumed = stored != null && restored != null
        ? resumeDeck(this.quotes, _random, stored.queueIds, lastId: stored.lastId)
        : null;
    if (stored != null && restored != null && resumed != null) {
      _deck = resumed;
      _seen = restored;
      _index = stored.index;
      return;
    }
    _deck = QuoteDeck(this.quotes, _random);
    final first = _deck.draw();
    if (first == null) return;
    _seen = [first];
    _index = 0;
  }

  final List<Quote> quotes;
  final double Function() _random;
  late final QuoteDeck _deck;
  List<Quote> _seen = [];
  int _index = 0;
  Quote? _held;

  Quote? get current => _index >= 0 && _index < _seen.length ? _seen[_index] : null;

  bool canFollow(double deltaY) => deltaY < 0 || _index > 0;

  /// The teaching a finger would reveal, without leaving the current one.
  /// Looking ahead draws from the deck once and keeps that draw until it is shown.
  Quote? peek(int direction) {
    final next = _index + direction;
    if (next < 0) return null;
    if (next < _seen.length) return _seen[next];
    if (direction < 0) return null;
    _held ??= _deck.draw();
    return _held;
  }

  Quote? advance(int direction) {
    final next = _index + direction;
    if (next < 0) return null;
    if (next < _seen.length) {
      _index = next;
      return _seen[next];
    }
    final quote = _held ?? _deck.draw();
    _held = null;
    if (quote == null) return null;
    _seen.add(quote);
    _index = _seen.length - 1;
    return quote;
  }

  StoredScroll? remember(String pool) {
    if (current == null) return null;
    final deck = _deck.snapshot();
    return StoredScroll(
      v: 1,
      pool: pool,
      queueIds: deck.queueIds,
      lastId: deck.lastId,
      seenIds: _seen.map((quote) => quote.id).toList(),
      index: _index,
    );
  }
}
