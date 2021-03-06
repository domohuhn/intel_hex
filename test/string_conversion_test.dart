// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:intel_hex/src/string_conversion.dart';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:intel_hex/src/exceptions.dart';

void main() {
  group('Create records', () {
    test('Data', () {
      var data = Uint8List(3);
      data[0] = 0x02;
      data[1] = 0x33;
      data[2] = 0x7A;
      expect(createDataRecord(0x0030, data), ":0300300002337A1E\n");
    });

    test('Extended Segment Address', () {
      expect(
          createExtendedSegmentAddressRecord(16 * 0x1200), ":020000021200EA\n");
    });
    test('Extended Segment Address2', () {
      expect(createExtendedSegmentAddressRecord(0x10000), ":020000021000EC\n");
    });

    test('Extended Linear Address', () {
      expect(
          createExtendedLinearAddressRecord(0xFFFF0000), ":02000004FFFFFC\n");
    });

    test('Start Linear Address', () {
      expect(createStartLinearAddressRecord(0xCD), ":04000005000000CD2A\n");
    });

    test('Start Segment Address', () {
      expect(createStartSegmentAddressRecord(0x0000, 0x3800),
          ":0400000300003800C1\n");
    });
    test('End of file', () {
      expect(createEndOfFileRecord(), ":00000001FF\n");
    });
  });

  group('Errors when creating records', () {
    test('Data address error', () {
      var data = Uint8List(3);
      expect(() => createDataRecord(0x10030, data),
          throwsA(TypeMatcher<IHexRangeError>()));
    });

    test('Data size error', () {
      var data = Uint8List(256);
      expect(() => createDataRecord(0x0030, data),
          throwsA(TypeMatcher<IHexRangeError>()));
    });

    test('Extended Segment Address Range error', () {
      expect(() => createExtendedSegmentAddressRecord(16 * 0x10000),
          throwsA(TypeMatcher<IHexRangeError>()));
    });
  });
}
