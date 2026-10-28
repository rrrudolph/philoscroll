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
    return MaterialApp(
      title: 'PhiloScroll',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _materialTheme(PhiloPalette.light),
      darkTheme: _materialTheme(PhiloPalette.dark),
      builder: (context, child) {
        final palette = PhiloPalette.forBrightness(MediaQuery.platformBrightnessOf(context));
        return PhiloTheme(
          palette: palette,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: _overlay(palette),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: Scaffold(body: page),
    );
  }
}

ThemeData _materialTheme(PhiloPalette palette) {
  return ThemeData(
    brightness: palette.brightness,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
  );
}

SystemUiOverlayStyle _overlay(PhiloPalette palette) {
  final dark = palette.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: palette.bg,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
}

class _ClosedBook extends StatelessWidget {
  const _ClosedBook(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = PhiloTheme.of(context);
    return ColoredBox(
      key: const Key('scroll-bg'),
      color: palette.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, textAlign: TextAlign.center, style: quoteStyle(22, palette.text)),
        ),
      ),
    );
  }
}
