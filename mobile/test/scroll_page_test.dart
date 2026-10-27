import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/app.dart';
import 'package:philoscroll/src/fit.dart';
import 'package:philoscroll/src/gesture.dart';
import 'package:philoscroll/src/measure.dart';
import 'package:philoscroll/src/quote.dart';
import 'package:philoscroll/src/quote_card.dart';
import 'package:philoscroll/src/scroll_page.dart';
import 'package:philoscroll/src/session.dart';
import 'package:philoscroll/src/theme.dart';

import 'support.dart';

void main() {
  final quotes = loadTestQuotes();

  setUpAll(loadAppFonts);

  testWidgets('shows only the teaching and the author, in the dark', (tester) async {
    await pumpScroll(tester, quotes);
    final card = currentCard(tester);
    expect(card.quote.text.length, greaterThan(20));
    expect(quotes.any((quote) => quote.text == card.quote.text), isTrue);
    expect(quotes.any((quote) => quote.author == card.quote.author), isTrue);
    expect(find.byType(QuoteCard), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Switch), findsNothing);

    final text = tester.widget<Text>(find.byKey(const Key('quote-text')));
    final author = tester.widget<Text>(find.byKey(const Key('quote-author')));
    final background = tester.widget<ColoredBox>(find.byKey(const Key('scroll-bg'))).color;
    expect(text.style!.color, PhiloColors.text);
    expect(text.style!.fontStyle, FontStyle.italic);
    expect(text.style!.fontWeight, FontWeight.w400);
    expect(text.style!.fontFamily, quoteFontFamily);
    expect(text.style!.letterSpacing!, greaterThanOrEqualTo(0));
    expect(author.data, card.quote.author.toUpperCase());
    expect(author.style!.color, PhiloColors.muted);
    expect(author.style!.fontWeight, FontWeight.w500);
    expect(author.style!.fontFamily, authorFontFamily);
    expect(contrastRatio(text.style!.color!, background), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(author.style!.color!, background), greaterThanOrEqualTo(4.5));

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, PhiloColors.bg);

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(card.quote.author))), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(card.quote.text.substring(0, 24)))), findsOneWidget);
    handle.dispose();
  });

  testWidgets('changes the teaching only when the page is swiped', (tester) async {
    await pumpScroll(tester, quotes);
    final first = visibleText(tester);
    await tester.drag(find.byType(ScrollPage), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(visibleText(tester), first);

    await swipe(tester, -20);
    expect(visibleText(tester), first);

    await swipe(tester, -120);
    final second = visibleText(tester);
    expect(second, isNot(first));
    expect(quotes.any((quote) => quote.text == second), isTrue);

    await swipe(tester, 140);
    expect(visibleText(tester), first);
  });

  testWidgets('follows the finger, fades the line, and springs back on a short pull', (tester) async {
    await pumpScroll(tester, quotes);
    final first = visibleText(tester);
    final start = tester.getCenter(find.byType(ScrollPage));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, -70));
    await tester.pump();

    expect(shiftY(tester, CardRole.current), closeTo(-70, 0.1));
    expect(cardOpacity(tester, CardRole.current), closeTo(1 - 70 / swipeFadePx, 0.001));
    expect(cardOpacity(tester, CardRole.current), lessThan(0.65));
    expect(find.byType(QuoteCard), findsNWidgets(2));
    final travel = gap(tester);
    expect(travel, greaterThan(12));
    expect(shiftY(tester, CardRole.neighbor) - shiftY(tester, CardRole.current), closeTo(travel, 0.1));

    await gesture.moveBy(const Offset(0, 58));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(visibleText(tester), first);
    expect(find.byType(QuoteCard), findsOneWidget);
    expect(shiftY(tester, CardRole.current), 0);
    expect(cardOpacity(tester, CardRole.current), 1);
  });

  testWidgets('slides the next line in from where the finger left the last one', (tester) async {
    await pumpScroll(tester, quotes);
    final first = visibleText(tester);
    final start = tester.getCenter(find.byType(ScrollPage));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    final travel = shiftY(tester, CardRole.neighbor) - shiftY(tester, CardRole.current);
    await gesture.up();
    await tester.pump();

    expect(find.byType(QuoteCard), findsNWidgets(2));
    expect(shiftY(tester, CardRole.leaving), closeTo(-80, 0.1));
    expect(shiftY(tester, CardRole.arriving) - shiftY(tester, CardRole.leaving), closeTo(travel, 0.1));
    expect(cardOpacity(tester, CardRole.arriving), closeTo(80 / swipeFadePx, 0.001));
    expect(tester.widget<QuoteCard>(find.byKey(const ValueKey(CardRole.leaving))).quote.text, first);

    await tester.pumpAndSettle();
    expect(find.byType(QuoteCard), findsOneWidget);
    expect(visibleText(tester), isNot(first));
    expect(shiftY(tester, CardRole.current), 0);
  });

  testWidgets('remembers the teaching and browse position across a reload', (tester) async {
    final store = MemoryScrollStore();
    await pumpScroll(tester, quotes, store: store, key: const Key('open'));
    final first = visibleText(tester);
    await swipe(tester, -120);
    final second = visibleText(tester);
    expect(second, isNot(first));

    await pumpScroll(tester, quotes, store: store, random: () => 0.99, key: const Key('reopen'));
    expect(visibleText(tester), second);
    await swipe(tester, 140);
    expect(visibleText(tester), first);
  });

  testWidgets('replaces the line in place when motion is reduced', (tester) async {
    await pumpScroll(tester, quotes, reduceMotion: true);
    final first = visibleText(tester);
    final start = tester.getCenter(find.byType(ScrollPage));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pump();
    expect(find.byType(QuoteCard), findsOneWidget);
    expect(visibleText(tester), isNot(first));
    expect(shiftY(tester, CardRole.current), 0);
  });

  testWidgets('resists a pull backward from the first teaching', (tester) async {
    await pumpScroll(tester, quotes);
    final first = visibleText(tester);
    final start = tester.getCenter(find.byType(ScrollPage));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    final y = shiftY(tester, CardRole.current);
    expect(y, closeTo(dragOffset(100, false), 0.1));
    expect(y, lessThan(50));
    expect(find.byType(QuoteCard), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(visibleText(tester), first);
  });

  testWidgets('puts a second finger down on the teaching that is already arriving', (tester) async {
    await pumpScroll(tester, quotes);
    final first = visibleText(tester);
    await swipe(tester, -120, settle: false);
    expect(find.byType(QuoteCard), findsNWidgets(2));
    final arriving = visibleText(tester);
    expect(arriving, isNot(first));

    final start = tester.getCenter(find.byType(ScrollPage));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    expect(find.byType(QuoteCard), findsOneWidget);
    expect(visibleText(tester), arriving);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(visibleText(tester), arriving);
  });

  testWidgets('the longest teaching stays on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longest = quotes.reduce((best, quote) => quote.text.length > best.text.length ? quote : best);
    await pumpScroll(tester, [longest]);
    expect(tester.takeException(), isNull);
    final frame = frameFor(width: 320, height: 568);
    final text = tester.getRect(find.byKey(const Key('quote-text')));
    final author = tester.getRect(find.byKey(const Key('quote-author')));
    expect(text.top, greaterThanOrEqualTo(frame.padTop - 1));
    expect(author.bottom, lessThanOrEqualTo(568 - frame.padBottom + 1));
    expect(tester.widget<Text>(find.byKey(const Key('quote-text'))).style!.fontSize, greaterThanOrEqualTo(16));
  });

  testWidgets('a large text size still stays on the phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final longest = quotes.reduce((best, quote) => quote.text.length > best.text.length ? quote : best);
    await pumpScroll(tester, [longest]);
    expect(tester.takeException(), isNull);
    final author = tester.getRect(find.byKey(const Key('quote-author')));
    final text = tester.getRect(find.byKey(const Key('quote-text')));
    expect(text.top, greaterThanOrEqualTo(-1));
    expect(author.bottom, lessThanOrEqualTo(569));
  });

  testWidgets('says so when the teachings cannot be opened', (tester) async {
    await tester.pumpWidget(const PhiloApp(quotes: [], loadError: 'The teachings could not be opened.'));
    final message = tester.widget<Text>(find.text('The teachings could not be opened.'));
    final background = tester.widget<ColoredBox>(find.byKey(const Key('scroll-bg'))).color;
    expect(contrastRatio(message.style!.color!, background), greaterThanOrEqualTo(4.5));
    expect(find.byType(QuoteCard), findsNothing);
  });

  testWidgets('an empty list is a dark page with nothing to read', (tester) async {
    await pumpScroll(tester, const []);
    expect(find.byType(QuoteCard), findsNothing);
    expect(tester.widget<ColoredBox>(find.byKey(const Key('scroll-bg'))).color, PhiloColors.bg);
  });
}

Future<void> pumpScroll(
  WidgetTester tester,
  List<Quote> quotes, {
  ScrollStore? store,
  bool reduceMotion = false,
  double Function()? random,
  Key? key,
}) async {
  await tester.pumpWidget(
    PhiloApp(
      key: key,
      quotes: quotes,
      store: store,
      random: random ?? () => 0.42,
      reduceMotion: reduceMotion,
    ),
  );
  await tester.pump();
}

Future<void> swipe(WidgetTester tester, double dy, {bool settle = true}) async {
  final start = tester.getCenter(find.byType(ScrollPage));
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 180));
  await gesture.moveBy(Offset(0, dy));
  await gesture.up();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

QuoteCard currentCard(WidgetTester tester) {
  return tester.widget<QuoteCard>(
    find.byWidgetPredicate(
      (widget) => widget is QuoteCard && (widget.role == CardRole.current || widget.role == CardRole.arriving),
    ),
  );
}

String visibleText(WidgetTester tester) => currentCard(tester).quote.text;

double shiftY(WidgetTester tester, CardRole role) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byKey(ValueKey(role)), matching: find.byType(Transform)),
  );
  return transform.transform.getTranslation().y;
}

double cardOpacity(WidgetTester tester, CardRole role) {
  final opacity = tester.widget<Opacity>(
    find.descendant(of: find.byKey(ValueKey(role)), matching: find.byType(Opacity)),
  );
  return opacity.opacity;
}

double gap(WidgetTester tester) {
  final size = tester.getSize(find.byType(ScrollPage));
  final card = tester.widget<QuoteCard>(find.byKey(const ValueKey(CardRole.current)));
  final font = tester.widget<Text>(find.byKey(const Key('quote-text'))).style!.fontSize!;
  final frame = frameFor(width: size.width, height: size.height);
  return handoffTravel(blockHeight(card.quote, font, frame, card.scaler), size.height);
}
