// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:intel_hex/intel_hex.dart';
import 'package:intel_hex/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  final throwValueError = throwsA(TypeMatcher<IHexValueError>());
  group('Create Intel HEX files', () {
    test('Empty file', () {
      final hex = IntelHexFile();
      expect(hex.segments.length, 0);
      expect(hex.maxAddress, 0);
      expect(hex.toFileContents(), ":00000001FF\n");
      expect(hex.toString(), '"Intel HEX" : { "segments": [] }');
      expect(hex.fileExtensions()[0], '.hex');
    });

    test('Set line length', () {
      final hex = IntelHexFile();
      expect(() => hex.lineLength = 0, throwValueError);
      expect(() => hex.lineLength = 256, throwValueError);
      hex.lineLength = 42;
      expect(hex.lineLength, 42);
    });

    test('file with segment', () {
      final hex = IntelHexFile(address: 0x120, length: 0x20);
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, 0x140);
      expect(hex.toFileContents(),
          ":1001200000000000000000000000000000000000CF\n:1001300000000000000000000000000000000000BF\n:00000001FF\n");
      expect(hex.toString(),
          '"Intel HEX" : { "segments": [ {"start": 288,"end": 320}] }');
    });

    test('file add data', () {
      final hex = IntelHexFile(address: 0x0, length: 0x20);
      var data = <int>[];
      for (int i = 0; i < 0x130; ++i) {
        data.add(0xFF);
      }
      hex.addAll(0x10, data);
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, 0x140);
      for (int i = 0; i < 0x140; ++i) {
        expect(hex.segments.first.byte(i), i < 0x10 ? 0 : 0xFF);
      }
    });

    test('file from data', () {
      var data = <int>[];
      for (int i = 0; i < 0x130; ++i) {
        data.add(0xFF);
      }
      final hex = IntelHexFile.fromData(data, address: 0x10);
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, 0x140);
      for (int i = 0x10; i < 0x140; ++i) {
        expect(hex.segments.first.byte(i), 0xFF);
      }
    });

    test('merge segments', () {
      var data1 = <int>[];
      var data2 = <int>[];
      var data3 = <int>[];
      for (int i = 0; i < 0x10; ++i) {
        data1.add(0xFF);
        data2.add(0x00);
        data3.add(0x0F);
      }
      final hex = IntelHexFile.fromData(data1);
      hex.addAll(0x12, data2);
      hex.addAll(0x5, data3);
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, 0x22);
      for (int i = 0x0; i < 0x5; ++i) {
        expect(hex.segments.first.byte(i), 0xFF);
      }
      for (int i = 0x5; i < 0x15; ++i) {
        expect(hex.segments.first.byte(i), 0x0F);
      }
      for (int i = 0x15; i < 0x22; ++i) {
        expect(hex.segments.first.byte(i), 0x00);
      }
    });

    test('write file with overlapping segments', () {
      var data1 = <int>[];
      var data2 = <int>[];
      for (int i = 0; i < 0x10; ++i) {
        data1.add(0xFF);
        data2.add(0xAA);
      }
      final hex = IntelHexFile.fromData(data1);
      hex.addAll(0x20, data2);
      expect(hex.segments.length, 2);
      hex.segments[0].appendUint64(0);
      hex.segments[0].appendUint64(0);
      hex.segments[0].appendUint64(0);
      expect(hex.maxAddress, 0x30);
      expect(hex.segments[0].endAddress, 0x28);
      expect(hex.segments[1].address, 0x20);
      expect(
          () => hex.toFileContents(), throwsA(TypeMatcher<IHexRangeError>()));
      final str = hex.toFileContents(allowDuplicateAddresses: true);
      expect(str, """:10000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00
:1000100000000000000000000000000000000000E0
:080020000000000000000000D8
:10002000AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA30
:00000001FF\n""");
    });

    test('write start linear address', () {
      final hex = IntelHexFile();
      hex.startLinearAddress = 0x12345678;
      expect(hex.toFileContents(), ":0400000512345678E3\n:00000001FF\n");
    });

    test('write start segment address', () {
      final hex = IntelHexFile();
      var addr = StartSegmentAddress();
      addr.codeSegment = 0x1234;
      addr.instructionPointer = 0x5678;
      hex.startSegmentAddress = addr;
      expect(hex.toFileContents(), ":0400000312345678E5\n:00000001FF\n");
    });
  });

  group('Parse Intel HEX files', () {
    test('Empty file', () {
      final hex = IntelHexFile.fromString("");
      expect(hex.segments.length, 0);
      expect(hex.maxAddress, 0);
    });

    test('Only end segment file', () {
      final hex = IntelHexFile.fromString(":00000001FF\n");
      expect(hex.segments.length, 0);
      expect(hex.maxAddress, 0);
    });

    test('Ignore after end', () {
      final hex = IntelHexFile.fromString(":00000001FF\n:0213");
      expect(hex.segments.length, 0);
      expect(hex.maxAddress, 0);
    });

    test('parse duplicate addresses', () {
      var line1 = ":0400100000000000EC\n";
      var line2 = ":04000E0000000000EE\n";
      var line3 = ":0400120000000000EA\n";

      expect(() => IntelHexFile.fromString(line1 + line1),
          throwsA(TypeMatcher<IHexRangeError>()));
      expect(() => IntelHexFile.fromString(line1 + line2),
          throwsA(TypeMatcher<IHexRangeError>()));
      expect(() => IntelHexFile.fromString(line1 + line3),
          throwsA(TypeMatcher<IHexRangeError>()));
      var hex = IntelHexFile.fromString(line1 + line1 + line2 + line3,
          allowDuplicateAddresses: true);

      expect(hex.segments.length, 1);
      expect(hex.maxAddress, 0x16);
    });

    test('Parse I8HEX', () {
      final hex = IntelHexFile.fromString(i8HexString);
      final start = 0x0120;
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, start + 0x20);
      expect(hex.format, IntelHexFormat.i8HEX);
      expect(hex.segments.first.address, start);
      expect(hex.segments.first.byte(start), 0x19);
      expect(hex.segments.first.byte(start + 0x01), 0x4E);
      expect(hex.segments.first.byte(start + 0x1F), 0x21);
      expect(hex.toFileContents(), i8HexString);
    });

    test('Parse I16HEX', () {
      final hex = IntelHexFile.fromString(i16HexString);
      final start = 0x0120 + 0x10000;
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, start + 0x20);
      expect(hex.format, IntelHexFormat.i16HEX);
      expect(hex.segments.first.address, start);
      expect(hex.segments.first.byte(start), 0x19);
      expect(hex.segments.first.byte(start + 0x01), 0x4E);
      expect(hex.segments.first.byte(start + 0x1F), 0x21);
      expect(hex.toFileContents(format: IntelHexFormat.i16HEX), i16HexString);
    });

    test('Parse I32HEX', () {
      final hex = IntelHexFile.fromString(i32HexString);
      final start = 0x0120 + 0xFFFF0000;
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, start + 0x20);
      expect(hex.format, IntelHexFormat.i32HEX);
      expect(hex.segments.first.address, start);
      expect(hex.segments.first.byte(start), 0x19);
      expect(hex.segments.first.byte(start + 0x01), 0x4E);
      expect(hex.segments.first.byte(start + 0x1F), 0x21);
      expect(hex.toFileContents(), i32HexString);
      expect(() => hex.toFileContents(format: IntelHexFormat.i16HEX),
          throwsA(TypeMatcher<IHexRangeError>()));
    });

    test('Parse I8HEX - startToken \$ ', () {
      final changedStr = i8HexString.replaceAll(':', '\$');
      final hex = IntelHexFile.fromString(changedStr, startToken: '\$');
      final start = 0x0120;
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, start + 0x20);
      expect(hex.format, IntelHexFormat.i8HEX);
      expect(hex.segments.first.address, start);
      expect(hex.segments.first.byte(start), 0x19);
      expect(hex.segments.first.byte(start + 0x01), 0x4E);
      expect(hex.segments.first.byte(start + 0x1F), 0x21);
      expect(hex.toFileContents(), changedStr);
      expect(hex.toFileContents(startToken: ':'), i8HexString);
    });

    test('Parse I16HEX - startToken \$ ', () {
      final changedStr = i16HexString.replaceAll(':', '\$');
      final hex = IntelHexFile.fromString(changedStr, startToken: '\$');
      final start = 0x0120 + 0x10000;
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, start + 0x20);
      expect(hex.format, IntelHexFormat.i16HEX);
      expect(hex.segments.first.address, start);
      expect(hex.segments.first.byte(start), 0x19);
      expect(hex.segments.first.byte(start + 0x01), 0x4E);
      expect(hex.segments.first.byte(start + 0x1F), 0x21);
      expect(hex.toFileContents(format: IntelHexFormat.i16HEX), changedStr);
    });

    test('Parse I32HEX - startToken \$ ', () {
      final changedStr = i32HexString.replaceAll(':', '\$');
      final hex = IntelHexFile.fromString(changedStr, startToken: '\$');
      final start = 0x0120 + 0xFFFF0000;
      expect(hex.segments.length, 1);
      expect(hex.maxAddress, start + 0x20);
      expect(hex.format, IntelHexFormat.i32HEX);
      expect(hex.segments.first.address, start);
      expect(hex.segments.first.byte(start), 0x19);
      expect(hex.segments.first.byte(start + 0x01), 0x4E);
      expect(hex.segments.first.byte(start + 0x1F), 0x21);
      expect(hex.toFileContents(), changedStr);
    });

    test('Parse startSegment', () {
      final hex = IntelHexFile.fromString(startSegment);
      expect(hex.startLinearAddress, null);
      expect(hex.startSegmentAddress, isNot(null));
      expect(hex.startSegmentAddress!.instructionPointer, 0x3800);
      expect(hex.startSegmentAddress!.codeSegment, 0x0000);
    });

    test('Parse startSegment multiple', () {
      expect(() => IntelHexFile.fromString(startSegment + startSegment),
          throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Parse startLinear', () {
      final hex = IntelHexFile.fromString(startLinear);
      expect(hex.startLinearAddress, isNot(null));
      expect(hex.startSegmentAddress, null);
      expect(hex.startLinearAddress!, 0xCD);
    });

    test('Parse startLinear multiple', () {
      expect(() => IntelHexFile.fromString(startLinear + startLinear),
          throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Data size error - wrong byte length in record', () {
      expect(
          () => IntelHexFile.fromString(
              ":200130003F0156702B5E712B722B732146013421B7"),
          throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Data size error - too few bytes', () {
      expect(() => IntelHexFile.fromString(":100130"),
          throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Record type error', () {
      expect(
          () => IntelHexFile.fromString(
              ":100130063F0156702B5E712B722B732146013421C1"),
          throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Checksum error', () {
      expect(
          () => IntelHexFile.fromString(
              ":100130003F0256702B5E712B722B732146013421C7"),
          throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Conversion error', () {
      expect(() => IntelHexFile.fromString(":ZZ000001FF"),
          throwsA(TypeMatcher<IHexValueError>()));
    });
  });
}

final comments = """// this is a comment\n klihklt""";

final i8HexString = """:10012000194E79234623965778239EDA3F01B2CAA7
:100130003F0156702B5E712B722B732146013421C7
:00000001FF
""";

final i16HexString = ":020000021000EC\n$i8HexString";

final i32HexString = ":02000004FFFFFC\n$i8HexString";

final startSegment = ":0400000300003800C1\n";
final startLinear = ":04000005000000CD2A\n";
