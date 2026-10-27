import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('loads a regular-weight text italic, not a heavier display italic', () {
    final bytes = File('assets/fonts/SourceSerif4-Italic.ttf').readAsBytesSync();
    final face = readFace(bytes);
    expect(face.weight, 400);
    expect(face.weight, lessThan(500));
    expect(face.italic, isTrue);
    expect(face.italicAngle, lessThanOrEqualTo(-6));
    expect(face.italicAngle, greaterThanOrEqualTo(-12));
    final name = String.fromCharCodes(bytes);
    expect(bytes.indexOf('Italic'.codeUnits.first), greaterThanOrEqualTo(0));
    expect(name.contains('Italic'), isTrue);
  });
}
