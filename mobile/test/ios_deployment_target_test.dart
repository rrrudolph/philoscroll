import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App Store Connect rejects uploads that target iOS older than 15.0
/// after April 2027 (ITMS-90068).
void main() {
  test('the iOS app targets iOS 15 or later', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);')
        .allMatches(project)
        .map((match) => match.group(1)!)
        .toList();

    expect(targets, isNotEmpty);
    for (final target in targets) {
      final parts = target.split('.').map(int.parse).toList();
      final major = parts[0];
      final minor = parts.length > 1 ? parts[1] : 0;
      expect(
        major > 15 || (major == 15 && minor >= 0),
        isTrue,
        reason: 'IPHONEOS_DEPLOYMENT_TARGET $target is below iOS 15.0',
      );
    }
  });
}
