import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'feed.dart';
import 'fit.dart';
import 'gesture.dart';
import 'measure.dart';
import 'motion.dart';
import 'quote.dart';
import 'quote_card.dart';
import 'session.dart';
import 'theme.dart';

const handoffMs = 440;
const settleMs = 180;

class ScrollPage extends StatefulWidget {
  const ScrollPage({super.key, required this.quotes, this.store, this.random, this.reduceMotion = false});

  final List<Quote> quotes;
  final ScrollStore? store;
  final double Function()? random;
  final bool reduceMotion;

  @override
  State<ScrollPage> createState() => _ScrollPageState();
}

class _Drag {
  const _Drag(this.pointer, this.originY, this.originT);

  final int pointer;
  final double originY;
  final Duration originT;
}

class _Handoff {
  const _Handoff({
    required this.leaving,
    required this.arriving,
    required this.path,
    required this.startOpacity,
  });

  final Quote leaving;
  final Quote arriving;
  final HandoffPath path;
  final double startOpacity;
}

class _Snap {
  const _Snap({
    required this.fromY,
    required this.fromOpacity,
    required this.travel,
    this.neighbor,
    required this.neighborY,
    required this.neighborOpacity,
  });

  final double fromY;
  final double fromOpacity;
  final double travel;
  final Quote? neighbor;
  final double neighborY;
  final double neighborOpacity;
}

enum _Phase { rest, drag, handoff, snap }

class _ScrollPageState extends State<ScrollPage> with SingleTickerProviderStateMixin {
  late final TeachingFeed _feed;
  late final String _pool;
  late final AnimationController _motion;

  _Phase _phase = _Phase.rest;
  _Drag? _drag;
  _Handoff? _handoff;
  _Snap? _snap;
  Quote? _neighbor;
  double _visualDy = 0;
  double _shownOffset = 0;
  int _motionToken = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: handoffMs))
      ..addListener(() {
        if (!_disposed && mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || _disposed || !mounted) return;
        setState(() {
          _phase = _Phase.rest;
          _handoff = null;
          _snap = null;
          _neighbor = null;
          _visualDy = 0;
          _shownOffset = 0;
        });
      });
    _pool = scrollPoolKey(widget.quotes);
    _feed = TeachingFeed(quotes: widget.quotes, random: widget.random, stored: loadScroll(_pool, widget.store));
    _persist();
  }

  @override
  void dispose() {
    _disposed = true;
    _motion.dispose();
    super.dispose();
  }

  bool get _reduceMotion => widget.reduceMotion || MediaQuery.disableAnimationsOf(context);

  TextScaler get _scaler => MediaQuery.textScalerOf(context);

  Frame _frame() {
    final media = MediaQuery.of(context);
    return frameFor(
      width: media.size.width,
      height: media.size.height,
      safeTop: media.padding.top,
      safeBottom: media.padding.bottom,
      safeLeft: media.padding.left,
      safeRight: media.padding.right,
    );
  }

  double _travelFor(Quote quote) {
    final frame = _frame();
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final font = fittedQuoteFont(quote: quote, frame: frame, viewportWidth: width, scaler: _scaler);
    return handoffTravel(blockHeight(quote, font, frame, _scaler), height);
  }

  void _persist() {
    final remembered = _feed.remember(_pool);
    if (remembered == null) return;
    saveScroll(remembered, widget.store);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    if (_feed.current == null || _drag != null) return;
    _motionToken += 1;
    _motion.stop();
    _drag = _Drag(event.pointer, event.position.dy, event.timeStamp);
    setState(() {
      _phase = _Phase.rest;
      _handoff = null;
      _snap = null;
      _neighbor = null;
      _visualDy = 0;
      _shownOffset = 0;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final drag = _drag;
    if (drag == null || event.pointer != drag.pointer || _feed.current == null) return;
    final dy = event.position.dy - drag.originY;
    Quote? neighbor;
    if (!_reduceMotion && dy != 0 && _feed.canFollow(dy)) {
      neighbor = _feed.peek(dy < 0 ? 1 : -1);
    }
    setState(() {
      _phase = _Phase.drag;
      _visualDy = dy;
      _shownOffset = dragOffset(dy, _feed.canFollow(dy));
      _neighbor = neighbor;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    final drag = _drag;
    if (drag == null || event.pointer != drag.pointer) return;
    final deltaY = event.position.dy - drag.originY;
    final elapsedMs = (event.timeStamp - drag.originT).inMicroseconds / 1000;
    _drag = null;
    _settle(deltaY, elapsedMs);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final drag = _drag;
    if (drag == null || event.pointer != drag.pointer) return;
    _drag = null;
    _motionToken += 1;
    _motion.stop();
    _beginSnap();
  }

  void _settle(double deltaY, double elapsedMs) {
    final direction = swipeDirection(deltaY, elapsedMs, _feed.canFollow(deltaY));
    if (direction != null && _reduceMotion) {
      _feed.advance(direction);
      _persist();
      setState(() {
        _phase = _Phase.rest;
        _neighbor = null;
        _visualDy = 0;
        _shownOffset = 0;
      });
      return;
    }
    if (direction == null) {
      if (_shownOffset == 0 && _neighbor == null) {
        setState(() => _phase = _Phase.rest);
        return;
      }
      _beginSnap();
      return;
    }
    final leaving = _feed.current;
    final arriving = _feed.advance(direction);
    if (leaving == null || arriving == null) {
      _beginSnap();
      return;
    }
    _persist();
    _beginHandoff(direction, leaving, arriving);
  }

  void _beginHandoff(int direction, Quote leaving, Quote arriving) {
    final travel = _travelFor(leaving);
    final token = ++_motionToken;
    _motion.stop();
    _motion.value = 0;
    setState(() {
      _phase = _Phase.handoff;
      _neighbor = null;
      _handoff = _Handoff(
        leaving: leaving,
        arriving: arriving,
        path: handoffPath(dragY: _shownOffset, travel: travel, direction: direction),
        startOpacity: swipeOpacity(_shownOffset),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _motionToken || _phase != _Phase.handoff) return;
      _motion.duration = const Duration(milliseconds: handoffMs);
      _motion.forward(from: 0);
    });
  }

  void _beginSnap() {
    final quote = _feed.current;
    if (quote == null || _reduceMotion) {
      setState(() {
        _phase = _Phase.rest;
        _neighbor = null;
        _visualDy = 0;
        _shownOffset = 0;
      });
      return;
    }
    final travel = MediaQuery.sizeOf(context).height == 0 ? 0.0 : _travelFor(quote);
    final direction = _visualDy < 0 ? 1 : -1;
    final neighbor = _neighbor;
    _motion.stop();
    _motion.value = 0;
    setState(() {
      _phase = _Phase.snap;
      _snap = _Snap(
        fromY: _shownOffset,
        fromOpacity: swipeOpacity(_shownOffset),
        travel: travel,
        neighbor: neighbor,
        neighborY: neighbor == null ? 0 : _shownOffset + direction * travel,
        neighborOpacity: neighbor == null ? 0 : 1 - swipeOpacity(_shownOffset),
      );
      _neighbor = null;
    });
    _motion.duration = const Duration(milliseconds: settleMs);
    _motion.forward(from: 0);
  }

  QuoteCard _card({
    required Quote quote,
    required CardRole role,
    required double dy,
    required double opacity,
    required bool semantics,
  }) {
    final frame = _frame();
    return QuoteCard(
      key: ValueKey(role),
      quote: quote,
      dy: dy,
      opacity: opacity,
      role: role,
      semantics: semantics,
      frame: frame,
      scaler: _scaler,
      fontSize: fittedQuoteFont(
        quote: quote,
        frame: frame,
        viewportWidth: MediaQuery.sizeOf(context).width,
        scaler: _scaler,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: ColoredBox(
          key: const Key('scroll-bg'),
          color: PhiloColors.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.15),
                    radius: 1.05,
                    colors: [PhiloColors.glow, Color(0x00B7C9A3)],
                    stops: [0, 0.68],
                  ),
                ),
              ),
              ..._cards(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cards() {
    final current = _feed.current;
    if (current == null) return const [];
    final t = Curves.easeOut.transform(_motion.value.clamp(0, 1));
    final handoff = _handoff;
    if (_phase == _Phase.handoff && handoff != null) {
      return [
        _card(
          quote: handoff.leaving,
          role: CardRole.leaving,
          dy: handoff.path.leaveY(t),
          opacity: _lerp(handoff.startOpacity, 0, t),
          semantics: false,
        ),
        _card(
          quote: handoff.arriving,
          role: CardRole.arriving,
          dy: handoff.path.arriveY(t),
          opacity: _lerp(1 - handoff.startOpacity, 1, t),
          semantics: true,
        ),
      ];
    }
    final snap = _snap;
    if (_phase == _Phase.snap && snap != null) {
      final cards = <Widget>[];
      final neighbor = snap.neighbor;
      if (neighbor != null) {
        final away = snap.neighborY >= 0 ? snap.travel : -snap.travel;
        cards.add(
          _card(
            quote: neighbor,
            role: CardRole.neighbor,
            dy: _lerp(snap.neighborY, away, t),
            opacity: _lerp(snap.neighborOpacity, 0, t),
            semantics: false,
          ),
        );
      }
      cards.add(
        _card(
          quote: current,
          role: CardRole.current,
          dy: _lerp(snap.fromY, 0, t),
          opacity: _lerp(snap.fromOpacity, 1, t),
          semantics: true,
        ),
      );
      return cards;
    }
    final cards = <Widget>[
      _card(quote: current, role: CardRole.current, dy: _shownOffset, opacity: swipeOpacity(_shownOffset), semantics: true),
    ];
    final neighbor = _neighbor;
    if (_phase == _Phase.drag && neighbor != null && _visualDy != 0) {
      final direction = _visualDy < 0 ? 1 : -1;
      cards.add(
        _card(
          quote: neighbor,
          role: CardRole.neighbor,
          dy: _shownOffset + direction * _travelFor(current),
          opacity: 1 - swipeOpacity(_shownOffset),
          semantics: false,
        ),
      );
    }
    return cards;
  }
}

double _lerp(double from, double to, double t) => from + (to - from) * t;
