import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/quote.dart';
import 'package:philoscroll/src/quotes.dart';

List<Quote> loadTestQuotes() {
  final raw = jsonDecode(File('assets/data.json').readAsStringSync());
  return loadQuotes(raw);
}

int jsInt32(int value) {
  final bits = value & 0xFFFFFFFF;
  return bits >= 0x80000000 ? bits - 0x100000000 : bits;
}

int jsUint32(int value) => value & 0xFFFFFFFF;

int imul(int a, int b) => jsInt32(jsInt32(a) * jsInt32(b));

double Function() mulberry32(int seed) {
  var state = seed;
  return () {
    state = jsInt32(state + 0x6d2b79f5);
    final mixed = jsUint32(state) >> 15;
    var t = imul(state ^ mixed, 1 | state);
    final shifted = jsUint32(t) >> 7;
    t = jsInt32(jsInt32(t + imul(t ^ shifted, 61 | t)) ^ t);
    return jsUint32(t ^ (jsUint32(t) >> 14)) / 4294967296;
  };
}

class FaceFacts {
  const FaceFacts({required this.weight, required this.italicAngle, required this.italic});

  final int weight;
  final double italicAngle;
  final bool italic;
}

FaceFacts readFace(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tables = data.getUint16(4);
  var os2 = -1;
  var post = -1;
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    final offset = data.getUint32(record + 8);
    if (tag == 'OS/2') os2 = offset;
    if (tag == 'post') post = offset;
  }
  if (os2 < 0 || post < 0) {
    throw StateError('font is missing OS/2 or post');
  }
  return FaceFacts(
    weight: data.getUint16(os2 + 4),
    italicAngle: data.getInt32(post + 4) / 65536,
    italic: (data.getUint16(os2 + 62) & 1) == 1,
  );
}

bool _fontsLoaded = false;

Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_fontsLoaded) return;
  final serif = File('assets/fonts/SourceSerif4-Italic.ttf').readAsBytesSync();
  final sans = File('assets/fonts/Outfit.ttf').readAsBytesSync();
  final serifLoader = FontLoader('Source Serif 4')..addFont(Future.value(ByteData.sublistView(serif)));
  final sansLoader = FontLoader('Outfit')..addFont(Future.value(ByteData.sublistView(sans)));
  await serifLoader.load();
  await sansLoader.load();
  _fontsLoaded = true;
}
