// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:intel_hex/intel_hex.dart';
import 'package:test/test.dart';

void main() {
  group('Performance', () {
    final hex = IntelHexFile(address: 0x0, length: 0x00);
    var data = <int>[];
    for (int i = 0; i < 0x100000; ++i) {
      data.add(0xFF & i);
    }
    hex.addAll(0x00, data);

    test('serialize 1mb', () {
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, 0x100000);

      final stopwatch = Stopwatch();
      stopwatch.start();
      final output = hex.toFileContents();
      stopwatch.stop();
      expect(output.length, 2883836);
      expect(stopwatch.elapsed < Duration(seconds: 1), true);
    });

    test('parse 1mb', () {
      final input = hex.toFileContents();

      final stopwatch = Stopwatch();
      stopwatch.start();
      final hex2 = IntelHexFile.fromString(input);
      stopwatch.stop();
      expect(hex2.segments.length, 1);
      expect(hex2.maxAddress, 0x100000);
      expect(stopwatch.elapsed < Duration(seconds: 1), true);
    });
  });
}
