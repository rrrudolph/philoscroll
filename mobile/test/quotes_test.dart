import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/quotes.dart';

import 'support.dart';

void main() {
  final quotes = loadTestQuotes();

  test('reads the lines and authors from data.json', () {
    expect(quotes.length, greaterThanOrEqualTo(50));
    expect(quotes.first.id, '1');
    expect(quotes.first.author, 'Evagrios the Solitary');
    for (final name in [
      'St. Antony the Great',
      'St. Isaiah the Solitary',
      'Evagrios the Solitary',
      'St. Mark the Ascetic',
    ]) {
      expect(quotes.any((quote) => quote.author == name), isTrue);
    }
    for (final quote in quotes) {
      expect(quote.text.length, greaterThan(20));
      expect(quote.author, isNotEmpty);
    }
  });

  test('the bundled teachings are the web app teachings', () {
    final bundled = File('assets/data.json').readAsBytesSync();
    final source = File('../data.json').readAsBytesSync();
    expect(bundled, source);
  });

  test('rejects two teachings with the same words', () {
    final first = quotes.first;
    expect(
      () => loadQuotes([
        {'id': 1, 'text': first.text, 'author': first.author},
        {'id': 2, 'text': first.text, 'author': first.author},
      ]),
      throwsA(isA<QuoteDataException>().having((error) => error.message, 'message', contains('words'))),
    );
  });

  test('rejects a teaching that is missing its words or its author', () {
    expect(
      () => loadQuotes([
        {'id': 1, 'text': 'A line with enough words to count.', 'author': ''},
      ]),
      throwsA(isA<QuoteDataException>().having((error) => error.message, 'message', contains('teachings'))),
    );
    expect(
      () => loadQuotes([
        {'id': 1, 'text': '   ', 'author': 'Someone'},
      ]),
      throwsA(isA<QuoteDataException>().having((error) => error.message, 'message', contains('teachings'))),
    );
  });
}
