import 'quote.dart';

class QuoteDataException implements Exception {
  QuoteDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

List<Quote> loadQuotes(Object? data) {
  if (data is! List || data.isEmpty || !data.every(isRawQuote)) {
    throw QuoteDataException('Expected a list of teachings.');
  }
  final quotes = data.map((item) {
    final quote = item as Map;
    return Quote(
      id: quote['id'].toString(),
      text: (quote['text'] as String).trim(),
      author: (quote['author'] as String).trim(),
    );
  }).toList();
  final ids = quotes.map((quote) => quote.id).toSet();
  if (ids.length != quotes.length) {
    throw QuoteDataException('Each teaching needs its own id.');
  }
  final bodies = quotes.map((quote) => '${quote.text}\u0000${quote.author}').toSet();
  if (bodies.length != quotes.length) {
    throw QuoteDataException('Each teaching needs its own words.');
  }
  return quotes;
}

bool isRawQuote(Object? value) {
  if (value is! Map) return false;
  final id = value['id'];
  final text = value['text'];
  final author = value['author'];
  final idOk = id is num || (id is String && id.isNotEmpty);
  return idOk &&
      text is String &&
      text.trim().isNotEmpty &&
      author is String &&
      author.trim().isNotEmpty;
}
