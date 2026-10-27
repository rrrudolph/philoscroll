import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/measure.dart';
import 'src/quote.dart';
import 'src/scroll_page.dart';
import 'src/session.dart';
import 'src/theme.dart';

class PhiloApp extends StatelessWidget {
  const PhiloApp({
    super.key,
    required this.quotes,
    this.store,
    this.random,
    this.reduceMotion = false,
    this.loadError,
  });

  final List<Quote> quotes;
  final ScrollStore? store;
  final double Function()? random;
  final bool reduceMotion;
  final String? loadError;

  @override
  Widget build(BuildContext context) {
    final page = loadError == null
        ? ScrollPage(quotes: quotes, store: store, random: random, reduceMotion: reduceMotion)
        : _ClosedBook(loadError!);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: PhiloColors.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'Philokalia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: PhiloColors.bg,
          canvasColor: PhiloColors.bg,
        ),
        home: Scaffold(backgroundColor: PhiloColors.bg, body: page),
      ),
    );
  }
}

class _ClosedBook extends StatelessWidget {
  const _ClosedBook(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('scroll-bg'),
      color: PhiloColors.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, textAlign: TextAlign.center, style: quoteStyle(22)),
        ),
      ),
    );
  }
}
