// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:typed_data';

import 'package:intel_hex/intel_hex.dart';
import 'package:intel_hex/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('Basic operations on segments', () {
    test('Create empty segment', () {
      var segment = MemorySegment(address: 0x42);
      expect(segment.address, 0x42);
      expect(segment.length, 0x00);
    });

    test('Create segment', () {
      var segment = MemorySegment(address: 0x42, length: 32);
      expect(segment.address, 0x42);
      expect(segment.length, 0x20);
    });

    test('Iterator error', () {
      var segment = MemorySegment(address: 0x42);
      var itr = segment.iterator;
      expect(() => itr.current, throwsA(TypeMatcher<IHexValueError>()));
    });

    test('Check if in segment', () {
      var segment = MemorySegment(address: 0x42, length: 32);
      expect(segment.isInRange(0x41, 1), false);
      expect(segment.isInRange(0x42, 1), true);
      expect(segment.isInRange(0x42, 32), true);
      expect(segment.isInRange(0x42 + 31, 1), true);
      expect(segment.isInRange(0x42 + 32, 1), false);
      expect(() => segment.byte(0xFF), throwsA(TypeMatcher<IHexRangeError>()));
      expect(() => segment.writeByte(0xFF, 42),
          throwsA(TypeMatcher<IHexRangeError>()));
      expect(() => segment.writeBytes(0xFF, Uint8List(42)),
          throwsA(TypeMatcher<IHexRangeError>()));
    });

    test('Append byte to segment', () {
      var segment = MemorySegment(address: 0x42);
      segment.append(25);
      expect(segment.address, 0x42);
      expect(segment.length, 0x01);
      expect(segment.byte(0x42), 25);
      segment.append(26);
      expect(segment.address, 0x42);
      expect(segment.length, 0x02);
      expect(segment.byte(0x42), 25);
      expect(segment.byte(0x43), 26);
      segment.writeByte(0x42, 255);
      expect(segment.byte(0x42), 255);
    });

    test('Append list of bytes to segment', () {
      var segment = MemorySegment(address: 0x10);
      List<int> data1 = [1, 2, 3, 4, 5, 6];
      List<int> data2 = [7, 8, 9];
      segment.appendAll(data1);
      expect(segment.address, 0x10);
      expect(segment.length, 0x06);
      for (int i = 0; i < 6; ++i) {
        expect(segment.byte(0x10 + i), i + 1);
      }
      segment.appendAll(data2);
      expect(segment.address, 0x10);
      expect(segment.length, 0x09);
      for (int i = 0; i < 9; ++i) {
        expect(segment.byte(0x10 + i), i + 1);
      }
    });

    test('Create from list of bytes and iterate', () {
      List<int> data1 = [1, 2, 3, 4, 5, 6];
      var segment = MemorySegment.fromBytes(address: 0x10, data: data1);
      expect(segment.address, 0x10);
      expect(segment.length, 0x06);
      expect(segment.endAddress, 0x16);
      int i = 0;
      for (var b in segment) {
        expect(b.address, 0x10 + i);
        expect(b.value, i + 1);
        ++i;
      }
    });

    test('Segments overlap', () {
      final segment1 = MemorySegment(address: 0, length: 32);
      final segment2 = MemorySegment(address: 16, length: 32);
      final segment3 = MemorySegment(address: 32, length: 32);
      final segment4 = MemorySegment(address: 64, length: 32);
      expect(segment1.overlaps(segment1), true);
      expect(segment1.overlaps(segment2), true);
      expect(segment1.overlaps(segment3), true);
      expect(segment1.overlaps(segment4), false);

      expect(segment2.overlaps(segment1), true);
      expect(segment2.overlaps(segment2), true);
      expect(segment2.overlaps(segment3), true);
      expect(segment2.overlaps(segment4), false);

      expect(segment3.overlaps(segment1), true);
      expect(segment3.overlaps(segment2), true);
      expect(segment3.overlaps(segment3), true);
      expect(segment3.overlaps(segment4), true);

      expect(segment4.overlaps(segment1), false);
      expect(segment4.overlaps(segment2), false);
      expect(segment4.overlaps(segment3), true);
      expect(segment4.overlaps(segment4), true);
    });

    test('Fill segments', () {
      final segment1 = MemorySegment(address: 0, length: 32);
      segment1.fill(25);
      for (var b in segment1) {
        expect(b.value, 25);
      }
    });

    test('Combine segments', () {
      final segment1 = MemorySegment(address: 0, length: 32);
      final segment2 = MemorySegment(address: 16, length: 32);
      final segment3 = MemorySegment(address: 32, length: 32);
      segment1.fill(25);
      segment2.fill(26);
      segment3.fill(27);
      for (var b in segment2) {
        expect(b.value, 26);
      }

      segment2.combine(segment2);
      expect(segment2.address, 16);
      expect(segment2.length, 32);
      expect(segment2.endAddress, 48);
      for (var b in segment2) {
        expect(b.value, 26);
      }

      segment2.combine(segment1);
      expect(segment2.address, 0);
      expect(segment2.length, 48);
      expect(segment2.endAddress, 48);
      for (var b in segment2) {
        expect(b.value, b.address < 32 ? 25 : 26);
      }

      segment2.combine(segment3);
      expect(segment2.address, 0);
      expect(segment2.length, 64);
      expect(segment2.endAddress, 64);
      for (var b in segment2) {
        expect(b.value, b.address < 32 ? 25 : 27);
      }

      segment1.combine(segment3);
      expect(segment1.address, 0);
      expect(segment1.length, 64);
      expect(segment1.endAddress, 64);
      for (var b in segment1) {
        expect(b.value, b.address < 32 ? 25 : 27);
      }
    });
  });

  group('Segment to file fragment', () {
    List<int> data = [];
    for (int i = 0; i < 32; ++i) {
      data.add(i);
    }
    final segment = MemorySegment.fromBytes(address: 0x20, data: data);
    const rv16Bytes =
        ":10002000000102030405060708090A0B0C0D0E0F58\n:10003000101112131415161718191A1B1C1D1E1F48\n";

    test('to I8HEX, 16 bytes', () {
      var rv = segmentToI8FileContents(segment, ":", 16);
      expect(rv, rv16Bytes);
    });

    test('to I8HEX, 64 bytes', () {
      var rv = segmentToI8FileContents(segment, ":", 64);
      expect(rv,
          ":20002000000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1FD0\n");
    });

    test('to I8HEX, 8 bytes', () {
      var rv = segmentToI8FileContents(segment, ":", 8);
      expect(rv,
          ":080020000001020304050607BC\n:0800280008090A0B0C0D0E0F74\n:0800300010111213141516172C\n:0800380018191A1B1C1D1E1FE4\n");
    });

    test('to I16HEX, 16 bytes', () {
      var rv = segmentToI16FileContents(segment, ":", 16);
      expect(rv, rv16Bytes);
    });

    test('to I32HEX, 16 bytes', () {
      var rv = segmentToI32FileContents(segment, ":", 16);
      expect(rv, rv16Bytes);
    });
  });

  group('Large segment to file fragment', () {
    List<int> data = [];
    for (int i = 0; i < 1024 * 128; ++i) {
      data.add(i);
    }
    final segment = MemorySegment.fromBytes(address: 0x20, data: data);
    test('to I8HEX, 16 bytes per line', () {
      expect(() => segmentToI8FileContents(segment, ":", 16),
          throwsA(TypeMatcher<IHexRangeError>()));
    });

    test('to I16HEX, 128 bytes per line', () {
      var rv = segmentToI16FileContents(segment, ":", 128);
      int count = '\n'.allMatches(rv).length;
      expect(count, 1025);
      expect(rv.contains(":020000021000EC\n"), true);
    });

    test('to I32HEX, 128 bytes per line', () {
      var rv = segmentToI32FileContents(segment, ":", 128);
      int count = '\n'.allMatches(rv).length;
      expect(count, 1025);
      expect(rv.contains(":020000040001F9\n"), true);
    });
  });

  group('Append data', () {
    var segment = MemorySegment(address: 0);
    setUp(() {
      segment = MemorySegment(address: 0);
    });

    test('add uint8', () {
      segment.appendUint8(0x42);
      expect(segment.length, 1);
      expect(segment.byte(0), 0x42);
    });

    test('add uint16', () {
      segment.appendUint16(0x1234);
      expect(segment.length, 2);
      expect(segment.byte(0), 0x34);
      expect(segment.byte(1), 0x12);
    });

    test('add uint32', () {
      segment.appendUint32(0x12345678);
      expect(segment.length, 4);
      expect(segment.byte(0), 0x78);
      expect(segment.byte(1), 0x56);
      expect(segment.byte(2), 0x34);
      expect(segment.byte(3), 0x12);
    });

    test('add uint64', () {
      segment.appendUint64(0x1122334455667788);
      expect(segment.length, 8);
      expect(segment.byte(0), 0x88);
      expect(segment.byte(1), 0x77);
      expect(segment.byte(2), 0x66);
      expect(segment.byte(3), 0x55);
      expect(segment.byte(4), 0x44);
      expect(segment.byte(5), 0x33);
      expect(segment.byte(6), 0x22);
      expect(segment.byte(7), 0x11);
    });

    test('add int8', () {
      segment.appendInt8(0x42);
      expect(segment.length, 1);
      expect(segment.byte(0), 0x42);
    });

    test('add int16', () {
      segment.appendInt16(0x1234);
      expect(segment.length, 2);
      expect(segment.byte(0), 0x34);
      expect(segment.byte(1), 0x12);
    });

    test('add int32', () {
      segment.appendInt32(0x12345678);
      expect(segment.length, 4);
      expect(segment.byte(0), 0x78);
      expect(segment.byte(1), 0x56);
      expect(segment.byte(2), 0x34);
      expect(segment.byte(3), 0x12);
    });
    test('add int32 big', () {
      segment.appendInt32(0x12345678, Endian.big);
      expect(segment.length, 4);
      expect(segment.byte(0), 0x12);
      expect(segment.byte(1), 0x34);
      expect(segment.byte(2), 0x56);
      expect(segment.byte(3), 0x78);
    });

    test('add int64', () {
      segment.appendInt64(0x1122334455667788);
      expect(segment.length, 8);
      expect(segment.byte(0), 0x88);
      expect(segment.byte(1), 0x77);
      expect(segment.byte(2), 0x66);
      expect(segment.byte(3), 0x55);
      expect(segment.byte(4), 0x44);
      expect(segment.byte(5), 0x33);
      expect(segment.byte(6), 0x22);
      expect(segment.byte(7), 0x11);
    });

    test('add float32', () {
      segment.appendFloat32(3.04);
      expect(segment.length, 4);
      expect(segment.byte(0), 92);
      expect(segment.byte(1), 143);
      expect(segment.byte(2), 66);
      expect(segment.byte(3), 64);
    });

    test('add float64', () {
      segment.appendFloat64(3.04);
      expect(segment.length, 8);
      expect(segment.byte(0), 82);
      expect(segment.byte(1), 184);
      expect(segment.byte(2), 30);
      expect(segment.byte(3), 133);
      expect(segment.byte(4), 235);
      expect(segment.byte(5), 81);
      expect(segment.byte(6), 8);
      expect(segment.byte(7), 64);
    });
  });
}
