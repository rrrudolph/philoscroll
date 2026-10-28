import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/app.dart';

import 'support.dart';

void main() {
  testWidgets('MaterialApp title is PhiloScroll, not Philokalia', (tester) async {
    await tester.pumpWidget(
      PhiloApp(quotes: loadTestQuotes()),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'PhiloScroll');
    expect(app.title, isNot(contains('Philokalia')));
  });
}
