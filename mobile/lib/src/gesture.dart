import 'dart:math' as math;

const swipeCommitPx = 56.0;
const swipeFadePx = 120.0;
const flickPxPerMs = 0.65;
const flickMinPx = 18.0;
const flickMinMs = 16.0;

/// 1 at rest, 0 once the finger has traveled [fadePx].
double swipeOpacity(double offsetPx, [double fadePx = swipeFadePx]) {
  if (!(fadePx > 0)) return 1;
  return 1 - math.min(1, offsetPx.abs() / fadePx);
}

/// Finger delta, or a short rubber-band when that direction has no teaching.
double dragOffset(double deltaY, bool canFollow) {
  if (canFollow) return deltaY;
  final sign = deltaY.sign;
  return sign * math.atan(deltaY.abs() / 180) * 72;
}

/// 1 is the next teaching, -1 is the previous one.
int? swipeDirection(double deltaY, double elapsedMs, bool canFollow) {
  if (!canFollow || deltaY == 0) return null;
  final distance = deltaY.abs();
  final flung = elapsedMs >= flickMinMs && distance >= flickMinPx && distance / elapsedMs >= flickPxPerMs;
  if (distance < swipeCommitPx && !flung) return null;
  return deltaY < 0 ? 1 : -1;
}
