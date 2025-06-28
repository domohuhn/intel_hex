// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:typed_data';
import 'package:intel_hex/src/exceptions.dart';
import 'package:intel_hex/intel_hex.dart';

/// Creates a data record from the given [address] and [data].
/// A data record contains a 16 bit address offset and up to 255 bytes of data.
///
/// The address must be able to fit in 2 bytes otherwise an exception is thrown.
/// The length of data must be less than 255 otherwise an exception is thrown.
///
/// Example: ":0300300002337A1E"
///
/// A different start token than ":" can be provided via [startCode].
String createDataRecord(int address, Uint8List data, {String startCode = ":"}) {
  if (address > 65535) {
    throw IHexRangeError("Address $address does not fit in two bytes!");
  }
  final byteCount = data.length;
  if (byteCount > 255) {
    throw IHexRangeError(
        "A maximum of 255 bytes of data can be in one data record! Got $byteCount");
  }
  var tmp = Uint8List(byteCount + 4);
  tmp[0] = byteCount;
  tmp[1] = (address >> 8) & 0xFF;
  tmp[2] = address & 0xFF;
  tmp[3] = 0x00;
  for (int i = 0; i < byteCount; ++i) {
    tmp[4 + i] = data[i];
  }
  return _convertToHexString(appendChecksum(tmp), startCode);
}

/// Creates an Extended Segment Address record from the given [address] and [data].
/// An Extended Segment Address contains a 16 bit address offset as payload. The payload must be multiplied by 16 and
/// is added to all subsequent addresses of DataRecords. This allows addressing up to 1 MB of memory.
///
/// The address must be able to fit in 2 bytes after it was divided by 16 otherwise an exception is thrown.
///
/// Example: ":020000021200EA"
///
/// A different start token than ":" can be provided via [startCode].
String createExtendedSegmentAddressRecord(int address,
    {String startCode = ":"}) {
  var computed = address >> 4;
  if (computed > 65535) {
    throw IHexRangeError("Address $address does not fit in two bytes!");
  }
  var tmp = Uint8List(6);
  tmp[0] = 0x02;
  tmp[1] = 0x00;
  tmp[2] = 0x00;
  tmp[3] = 0x02;
  tmp[4] = (computed >> 8) & 0xFF;
  tmp[5] = computed & 0xFF;
  return _convertToHexString(appendChecksum(tmp), startCode);
}

/// Creates an Extended Linear Address record from the given [address].
/// The record block contains the upper 16 bits of the addresses and is used for all
/// following data records. This allows addressing up to 4 GB of memory.
///
/// Example: ":02000004FFFFFC"
///
/// A different start token than ":" can be provided via [startCode].
String createExtendedLinearAddressRecord(int address,
    {String startCode = ":"}) {
  var computed = (address >> 16);
  var tmp = Uint8List(6);
  tmp[0] = 0x02;
  tmp[1] = 0x00;
  tmp[2] = 0x00;
  tmp[3] = 0x04;
  tmp[4] = (computed >> 8) & 0xFF;
  tmp[5] = computed & 0xFF;
  return _convertToHexString(appendChecksum(tmp), startCode);
}

/// Creates a Start Segment Address record from the given [address].
/// The record block contains 16 bits of the [codeSegment] and 16 bits
/// of the [instructionPointer].
/// For 80x86 processors, this record specifies the starting execution address.
///
/// Example: ":0400000300003800C1"
///
/// A different start token than ":" can be provided via [startCode].
String createStartSegmentAddressRecord(int codeSegment, int instructionPointer,
    {String startCode = ":"}) {
  var tmp = Uint8List(8);
  tmp[0] = 0x04;
  tmp[1] = 0x00;
  tmp[2] = 0x00;
  tmp[3] = 0x03;
  tmp[4] = (codeSegment >> 8) & 0xFF;
  tmp[5] = codeSegment & 0xFF;
  tmp[6] = (instructionPointer >> 8) & 0xFF;
  tmp[7] = instructionPointer & 0xFF;
  return _convertToHexString(appendChecksum(tmp), startCode);
}

/// Creates a Start Linear Address record from the given [address].
/// The record block contains 32 bits of the address and describes
/// the starting execution address for CPUs that support it.
///
/// Example: ":04000005000000CD2A"
///
/// A different start token than ":" can be provided via [startCode].
String createStartLinearAddressRecord(int address, {String startCode = ":"}) {
  var tmp = Uint8List(8);
  tmp[0] = 0x04;
  tmp[1] = 0x00;
  tmp[2] = 0x00;
  tmp[3] = 0x05;
  tmp[4] = (address >> 24) & 0xFF;
  tmp[5] = (address >> 16) & 0xFF;
  tmp[6] = (address >> 8) & 0xFF;
  tmp[7] = address & 0xFF;
  return _convertToHexString(appendChecksum(tmp), startCode);
}

/// Converts [data] to a String with hex values.
String _convertToHexString(Uint8List data, String startCode) {
  StringBuffer rv = StringBuffer();
  for (final value in data) {
    rv.write(value.toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return "$startCode$rv\n";
}

/// Creates the end of file record.
/// Must occur once per file.
///
/// A different start token than ":" can be provided via [startCode].
String createEndOfFileRecord({String startCode = ":"}) {
  return "${startCode}00000001FF\n";
}

/// The record type in a file
enum IHexRecordType {
  /// a data record (id 00)
  data,

  /// end of data (id 01)
  endOfFile,

  /// additional addressing up to 1 Mb (id 02)
  extendedSegmentAddress,

  /// Starting address for execution for 80x86 (id 03)
  startSegmentAddress,

  /// additional addressing up to 4 GB. Contains 16 high bits of the address (id 04)
  extendedLinearAddress,

  /// 32 bit address of the starting address (id 05)
  startLinearAddress
}

int _convertHexCodePointToInt(int codePoint) {
  if (0x30 <= codePoint && codePoint <= 0x39) {
    return codePoint - 0x30;
  }
  if (0x41 <= codePoint && codePoint <= 0x46) {
    return 10 + codePoint - 0x41;
  }
  if (0x61 <= codePoint && codePoint <= 0x66) {
    return 10 + codePoint - 0x61;
  }
  throw IHexValueError("Failed to convert code point $codePoint to a number.");
}

int _createU8FromUnicodeCodePoints(int highNibble, int lowNibble) {
  int hi = _convertHexCodePointToInt(highNibble);
  int lo = _convertHexCodePointToInt(lowNibble);
  return (hi << 4) | lo;
}

/// Represents a record read from a file.
class IHexRecord {
  IHexRecord(this.line, {int startCodePoint = 0x3A}) {
    List<int> parsed = [];
    final runes = line.runes.toList();
    final start = runes.indexOf(startCodePoint);
    if (start == -1) {
      throw IHexValueError(
          "Line contains no RECORD MARK '${String.fromCharCode(startCodePoint)}' - failed to find start of record!");
    }

    for (var i = start + 1; i + 1 < runes.length; i = i + 2) {
      parsed.add(_createU8FromUnicodeCodePoints(runes[i], runes[i + 1]));
    }
    if (parsed.length < 5) {
      throw IHexValueError(
          "Line is too short! The shortest possible record is 5 bytes - got ${parsed.length}");
    }
    data = Uint8List.fromList(parsed);
    if (!validateChecksum(data)) {
      throw IHexValueError("Checksum is not valid!");
    }
    if (data[0] != data.length - 5) {
      throw IHexValueError(
          "Length byte is not valid! Expected: ${data.length - 5} Got: ${data[0]}");
    }
    switch (data[3]) {
      case 0:
        recordType = IHexRecordType.data;
        break;
      case 1:
        recordType = IHexRecordType.endOfFile;
        break;
      case 2:
        recordType = IHexRecordType.extendedSegmentAddress;
        break;
      case 3:
        recordType = IHexRecordType.startSegmentAddress;
        break;
      case 4:
        recordType = IHexRecordType.extendedLinearAddress;
        break;
      case 5:
        recordType = IHexRecordType.startLinearAddress;
        break;
      default:
        throw IHexValueError(
            "Unknown record type! Expected: [0-5] Got: ${data[3]}");
    }
  }

  String line;
  Uint8List data = Uint8List(0);

  IHexRecordType recordType = IHexRecordType.data;

  /// Returns the payload of the record
  Uint8List get payload => Uint8List.sublistView(data, 4, data.length - 1);

  /// Gets the record address
  int get recordAddress => _read2ByteAddress(recordType, "", 1, data.length);

  /// Gets the extended segment address
  int get extendedSegmentAddress =>
      _read2ByteAddress(
          IHexRecordType.extendedSegmentAddress,
          "$recordType  with ${data.length} does not contain data for an extendedSegmentAddress (required 7 bytes)",
          4,
          7) *
      16;

  /// Gets the extended linear address
  int get extendedLinearAddress =>
      _read2ByteAddress(
          IHexRecordType.extendedLinearAddress,
          "$recordType  with ${data.length} does not contain data for an extendedLinearAddress (required 7 bytes)",
          4,
          7) <<
      16;

  /// Gets the extended linear address
  int get startLinearAddress => _read4ByteAddress(
      IHexRecordType.startLinearAddress,
      "$recordType  with ${data.length} does not contain data for an extendedLinearAddress (required 9 bytes)");

  /// Gets the start Segment Address
  StartSegmentAddress get startSegmentAddress {
    var addr = StartSegmentAddress();
    addr.codeSegment = _read2ByteAddress(
        IHexRecordType.startSegmentAddress,
        "$recordType  with ${data.length} does not contain data for an extendedLinearAddress (required 9 bytes)",
        4,
        9);
    addr.instructionPointer = _read2ByteAddress(
        IHexRecordType.startSegmentAddress,
        "$recordType  with ${data.length} does not contain data for an extendedLinearAddress (required 9 bytes)",
        6,
        9);
    return addr;
  }

  int _read2ByteAddress(
      IHexRecordType type, String errorMsg, int start, int size) {
    if (recordType != type || data.length != size) {
      throw IHexValueError(errorMsg);
    }
    int address = (data[start] << 8) | data[start + 1];
    return address;
  }

  int _read4ByteAddress(IHexRecordType type, String errorMsg) {
    if (recordType != type || data.length != 9) {
      throw IHexValueError(errorMsg);
    }
    int address = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
    return address;
  }
}
