import 'dart:math' as math;

class HandoffPath {
  const HandoffPath({
    required this.leaveStart,
    required this.leaveEnd,
    required this.arriveStart,
    required this.arriveEnd,
  });

  final double leaveStart;
  final double leaveEnd;
  final double arriveStart;
  final double arriveEnd;

  double leaveY(double t) => leaveStart + (leaveEnd - leaveStart) * t;
  double arriveY(double t) => arriveStart + (arriveEnd - arriveStart) * t;
}

HandoffPath handoffPath({required double dragY, required double travel, required int direction}) {
  final enterY = dragY + direction * travel;
  final exitY = direction == 1 ? math.min(dragY, -travel) : math.max(dragY, travel);
  return HandoffPath(leaveStart: dragY, leaveEnd: exitY, arriveStart: enterY, arriveEnd: 0);
}
