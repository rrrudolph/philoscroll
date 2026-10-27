import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/feed.dart';
import 'package:philoscroll/src/session.dart';

import 'support.dart';

void main() {
  final quotes = loadTestQuotes();

  test('previewing the next teaching does not skip it', () {
    final feed = TeachingFeed(quotes: quotes, random: mulberry32(3));
    final peeked = feed.peek(1);
    expect(feed.advance(1)?.id, peeked?.id);
  });

  test('looking ahead and then stepping back keeps that next teaching', () {
    final feed = TeachingFeed(quotes: quotes, random: mulberry32(5));
    feed.advance(1);
    final peeked = feed.peek(1);
    expect(feed.advance(-1)?.id, isNot(peeked?.id));
    expect(feed.advance(1)?.id, isNot(peeked?.id));
    expect(feed.advance(1)?.id, peeked?.id);
  });

  test('cannot step back before the first teaching', () {
    final feed = TeachingFeed(quotes: quotes, random: () => 0.2);
    expect(feed.canFollow(40), isFalse);
    expect(feed.advance(-1), isNull);
    expect(feed.canFollow(-40), isTrue);
  });

  test('remembers a place that can be opened again', () {
    final first = TeachingFeed(quotes: quotes, random: mulberry32(8));
    final pool = scrollPoolKey(quotes);
    final opening = first.current?.id;
    first.advance(1);
    final second = first.current?.id;
    final store = MemoryScrollStore();
    saveScroll(first.remember(pool)!, store);
    final reopened = TeachingFeed(quotes: quotes, random: () => 0.99, stored: loadScroll(pool, store));
    expect(reopened.current?.id, second);
    expect(reopened.advance(-1)?.id, opening);
  });
}
