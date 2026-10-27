import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/gesture.dart';

void main() {
  test('fades in step with the finger and is already dim at the commit point', () {
    expect(swipeOpacity(0), 1);
    expect(swipeOpacity(swipeFadePx / 2), closeTo(0.5, 1e-5));
    expect(swipeOpacity(swipeFadePx), 0);
    expect(swipeOpacity(swipeFadePx + 40), 0);
    expect(swipeOpacity(swipeCommitPx), lessThan(0.6));
    expect(swipeFadePx, lessThanOrEqualTo(140));
  });

  test('tracks the finger one to one, and only resists a dead end', () {
    expect(dragOffset(-80, true), -80);
    expect(dragOffset(80, true), 80);
    final resisted = dragOffset(100, false);
    expect(resisted, greaterThan(0));
    expect(resisted, lessThan(50));
  });

  test('changes teaching on a real swipe or a flick, not on a twitch', () {
    expect(swipeDirection(-10, 0, true), isNull);
    expect(swipeDirection(-(swipeCommitPx - 1), 400, true), isNull);
    expect(swipeDirection(-swipeCommitPx, 400, true), 1);
    expect(swipeDirection(swipeCommitPx, 200, true), -1);
    expect(swipeDirection(-20, 20, true), 1);
    expect(swipeDirection(80, 100, false), isNull);
  });
}
