import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/deck.dart';

import 'support.dart';

void main() {
  final quotes = loadTestQuotes();

  test('matches the shuffle source used by the web app', () {
    final random = mulberry32(1);
    expect(random(), closeTo(0.6270739405881613, 1e-12));
    expect(random(), closeTo(0.002735721180215478, 1e-12));
    expect(random(), closeTo(0.5274470399599522, 1e-12));
  });

  test('shows every teaching once before it repeats, and does not repeat the last one immediately', () {
    for (final seed in [1, 2, 7, 99, 12345]) {
      final deck = QuoteDeck(quotes, mulberry32(seed));
      final firstCycle = quotes.map((_) => deck.draw()?.id).toList();
      expect(firstCycle.every((id) => id is String), isTrue);
      expect(firstCycle.toSet().length, quotes.length);
      final next = deck.draw();
      expect(next?.id, isNot(firstCycle.last));
    }
  });

  test('can repeat when only one teaching is left', () {
    final only = quotes.first;
    final deck = QuoteDeck([only], () => 0);
    expect(deck.draw()?.id, only.id);
    expect(deck.draw()?.id, only.id);
  });

  test('returns nothing when there are no teachings', () {
    expect(QuoteDeck([]).draw(), isNull);
  });

  test('resumes the remaining shuffle after a snapshot', () {
    final deck = QuoteDeck(quotes, mulberry32(4));
    for (var i = 0; i < 12; i += 1) {
      deck.draw();
    }
    final snap = deck.snapshot();
    final resumed = resumeDeck(quotes, mulberry32(99), snap.queueIds, lastId: snap.lastId);
    expect(resumed, isNotNull);
    expect(resumed!.draw()?.id, deck.draw()?.id);
  });
}
