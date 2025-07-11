// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:intel_hex/src/exceptions.dart';
import 'package:intel_hex/src/memory_segment.dart';
import 'package:intel_hex/src/memory_segment_container.dart';
import 'package:intel_hex/src/string_conversion.dart';
import 'package:intel_hex/src/validation.dart';
import 'dart:math';

/// The format that is used to print the intel hex file.
///
enum IntelHexFormat {
  /// only uses record types 0 and 1. Max address is 65535 (65 kB).
  i8HEX,

  /// only uses record types 0 through 3. Max address is 1048560 (1 MB).
  i16HEX,

  /// only uses record types 0, 1, 4 and 5. Max address is 2^32 (4 GB).
  i32HEX
}

/// Data type representing the start segment address.
/// For 80x86 CPUs, this is the start address of the execution.
class StartSegmentAddress {
  /// Initial value of the instruction pointer. 16 bits.
  int instructionPointer = 0;

  /// Start address of the code segment. 16 bits.
  int codeSegment = 0;
}

/// This class represents the interface to read and write Intel hex files.
///
/// To parse a file, simply read it as string and call the fromString()
/// constructor. If you want to write a file with binary data, then
/// you can create an empty file and add your data by calling addAll().
///
/// The contents of the file are stored as [MemorySegment]. The segments
/// are managed in the base class [MemorySegmentContainer].
class IntelHexFile extends MemorySegmentContainer {
  /// The start address where the code is executed (for 80x86 CPUs).
  /// This value may be null if it is not contained in the file.
  StartSegmentAddress? startSegmentAddress;

  /// The start address where the code is executed (if supported by the CPU).
  /// This value may be null if it is not contained in the file.
  int? startLinearAddress;

  /// The start code for a record. The standard value is ":".
  String startCode = ":";

  /// Creates a file with a single segment if [address] is >= 0 and [length] is >= 0.
  /// Otherwise the file is empty.
  IntelHexFile({super.address, super.length});

  /// Creates a file with a single segment containing all bytes from [data].
  /// The start [address] is 0 unless another value is provided.
  ///
  /// The contents of [data] will be truncated to (0, 255).
  IntelHexFile.fromData(super.data, {super.address}) : super.fromData();

  /// Parses the Intel Hex records in the [data] string and adds it to the
  /// segments in this object. All lines without ":" are ignored. In lines with a colon all preceding
  /// characters are ignored. After the colon, only valid characters for hexadecimal numbers (0-9a-fA-F)
  /// are allowed up until the end of the line.
  ///
  /// May throw an error during parsing. Potential error cases are: a checksum that is not correct,
  /// a record with an unknown record type, a record where the given length is wrong, a record that
  /// can not be converted to integers or if records 3 or 5 occur multiple times.
  ///
  /// If a nonstandard start code should be used instead of ":", then you must provide it
  /// via the optional argument [startToken]. If the argument is provided, then [startCode] property will be set to its value.
  ///
  /// The constructor will also verify that every address in the data string is unique. You can prevent this
  /// check by setting [allowDuplicateAddresses] to true.
  IntelHexFile.fromString(String data,
      {String? startToken, bool allowDuplicateAddresses = false})
      : super() {
    if (startToken != null) {
      if (startToken.length != 1) {
        throw IHexValueError(
            "The startToken string can only be 1 character long, got ${startToken.length} - string: '$startToken'");
      }
      startCode = startToken;
    }
    int startCodePoint = startCode.codeUnits.first;
    int extendedSegmentAddress = 0;
    int extendedLinearAddress = 0;
    int lineNo = 1;

    final segmentBuilder = MemorySegmentContainerBuilder();
    for (int i = 0; i < data.codeUnits.length; ++i) {
      int currentCodeUnit = data.codeUnits[i];
      if (currentCodeUnit == startCodePoint) {
        // parse line, append to builder
        bool done = false;
        try {
          var record = IHexRecord.fromCodeUnits(data.codeUnits, i,
              startCodePoint: startCodePoint);
          switch (record.recordType) {
            case IHexRecordType.data:
              _addDataRecordToSegmentList(
                  segmentBuilder,
                  record,
                  extendedLinearAddress,
                  extendedSegmentAddress,
                  allowDuplicateAddresses);
              break;
            case IHexRecordType.endOfFile:
              done = true;
              break;
            case IHexRecordType.extendedSegmentAddress:
              extendedSegmentAddress = record.extendedSegmentAddress;
              break;
            case IHexRecordType.startSegmentAddress:
              if (startSegmentAddress != null) {
                throw IHexValueError(
                    "Start segment address record occurs more than once!");
              }
              startSegmentAddress = record.startSegmentAddress;
              break;
            case IHexRecordType.extendedLinearAddress:
              extendedLinearAddress = record.extendedLinearAddress;
              break;
            case IHexRecordType.startLinearAddress:
              if (startLinearAddress != null) {
                throw IHexValueError(
                    "Start linear address record occurs more than once!");
              }
              startLinearAddress = record.startLinearAddress;
              break;
          }
          i += record.stringLength;
        } catch (e) {
          throw IHexValueError("Parsing error on line $lineNo : $e");
        }
        if (done) {
          break;
        }
      }
      if (data.codeUnits[i] == 0x0A) {
        lineNo++;
      }
    }
    final toAdd =
        segmentBuilder.build(allowDuplicateAddresses: allowDuplicateAddresses);
    for (final newSegment in toAdd.segments) {
      addSegment(newSegment);
    }
  }

  /// Controls the number of bytes in a data record.
  ///
  /// Must be between 1 and 255.
  int get lineLength => _lineLength;

  set lineLength(int v) {
    _validateLineLength(v);
    _lineLength = v;
  }

  int _lineLength = 16;

  /// Converts this instance of IntelHexFile to an Intel Hex file record block.
  ///
  /// If a nonstandard start code should be used instead of ":", then you must provide it
  /// via the optional argument [startToken]. If the argument is provided, then startCode property will be set to its value.
  ///
  /// The method will also verify that every address in the segments is unique.
  /// You can prevent this check by setting [allowDuplicateAddresses] to true.
  String toFileContents(
      {IntelHexFormat format = IntelHexFormat.i32HEX,
      String? startToken,
      bool allowDuplicateAddresses = false}) {
    if (startToken != null) {
      startCode = startToken;
    }
    sortSegments();
    if (!allowDuplicateAddresses && !validateSegmentsAreUnique()) {
      throw IHexRangeError("There are overlapping Segments in the file!");
    }
    var rv = StringBuffer();
    if (startLinearAddress != null) {
      createStartLinearAddressRecord(rv, startLinearAddress!,
          startCode: startCode);
    }
    if (startSegmentAddress != null) {
      createStartSegmentAddressRecord(rv, startSegmentAddress!.codeSegment,
          startSegmentAddress!.instructionPointer,
          startCode: startCode);
    }

    for (final seg in segments) {
      _segmentToFileContents(rv, seg, format: format, startCode: startCode);
    }
    rv.write(createEndOfFileRecord(startCode: startCode));
    return rv.toString();
  }

  void _addDataRecordToSegmentList(
      MemorySegmentContainerBuilder out,
      IHexRecord record,
      int extendedLinearAddress,
      int extendedSegmentAddress,
      bool allowDuplicateAddresses) {
    final address =
        record.recordAddress + extendedLinearAddress + extendedSegmentAddress;
    final seg = MemorySegment.fromBytes(address: address, data: record.payload);
    out.add(seg);
  }

  /// Returns the format that can be used to represent the file.
  IntelHexFormat get format {
    final maxAddr = maxAddress;
    if (maxAddr <= 65536) {
      return IntelHexFormat.i8HEX;
    } else if (maxAddr <= 1048576) {
      return IntelHexFormat.i16HEX;
    }
    return IntelHexFormat.i32HEX;
  }

  /// Returns a list of possible file extensions for intel hex files
  List<String> fileExtensions() {
    return [
      ".hex",
      ".h86",
      ".hxl",
      ".hxh",
      ".obl",
      ".obh",
      ".mcs",
      ".ihex",
      ".ihe",
      ".ihx",
      ".a43",
      ".a90"
    ];
  }

  /// Prints information about the file and its contents.
  @override
  String toString() {
    return '"Intel HEX" : { ${super.toString()} }';
  }

  /// Converts this segment to an Intel Hex file record block.
  void _segmentToFileContents(StringBuffer str, MemorySegment seg,
      {IntelHexFormat format = IntelHexFormat.i32HEX, String startCode = ":"}) {
    switch (format) {
      case IntelHexFormat.i8HEX:
        segmentToI8FileContents(str, seg, startCode, _lineLength);
      case IntelHexFormat.i16HEX:
        segmentToI16FileContents(str, seg, startCode, _lineLength);
      case IntelHexFormat.i32HEX:
        segmentToI32FileContents(str, seg, startCode, _lineLength);
    }
  }
}

/// Converts the segment [seg] to an Intel Hex file record block with a max of 16 bit addresses.
///
/// Uses [startCode] to start a record and writes [lineLength] bytes per line.
/// [lineLength] must be between 1 and 255.
void segmentToI8FileContents(
    StringBuffer str, MemorySegment seg, String startCode, int lineLength) {
  _validateLineLength(lineLength);
  if (seg.endAddress > 65535) {
    throw IHexRangeError(
        "Address range [${seg.address},${seg.endAddress}] can not be represented as I8HEX (max. Range: [0,65535])");
  }
  for (int i = 0; i < seg.length; i = i + lineLength) {
    createDataRecord(
        str, seg.address + i, seg.slice(i, min(i + lineLength, seg.length)),
        startCode: startCode);
  }
}

/// Converts the segment [seg] to an Intel Hex file record block with a max size of 1 MB.
///
/// Uses [startCode] to start a record and writes [lineLength] bytes per line.
/// [lineLength] must be between 1 and 255.
void segmentToI16FileContents(
    StringBuffer str, MemorySegment seg, String startCode, int lineLength) {
  _validateLineLength(lineLength);
  const i16max = 65535;
  if (seg.endAddress > i16max * 16) {
    throw IHexRangeError(
        "Address range [${seg.address},${seg.endAddress}] can not be represented as I16HEX (max. Range: [0,1048560])");
  }
  var lastBlockAddress = 0;
  for (int i = 0; i < seg.length; i = i + lineLength) {
    final dataStartAddress = seg.address + i;
    final blockStartAddress = dataStartAddress & 0xF0000;
    if (blockStartAddress != lastBlockAddress) {
      createExtendedSegmentAddressRecord(str, blockStartAddress,
          startCode: startCode);
    }
    lastBlockAddress = blockStartAddress;
    createDataRecord(str, dataStartAddress & 0xFFFF,
        seg.slice(i, min(i + lineLength, seg.length)),
        startCode: startCode);
  }
}

/// Converts the segment [seg] to an Intel Hex file record block.
///
/// Uses [startCode] to start a record and writes [lineLength] bytes per line.
/// [lineLength] must be between 1 and 255.
void segmentToI32FileContents(
    StringBuffer str, MemorySegment seg, String startCode, int lineLength) {
  _validateLineLength(lineLength);
  validateAddressAndLength(seg.address, seg.length);
  var lastBlockAddress = 0;
  for (int i = 0; i < seg.length; i = i + lineLength) {
    final dataStartAddress = seg.address + i;
    final blockStartAddress = dataStartAddress & 0xFFFF0000;
    if (blockStartAddress != lastBlockAddress) {
      createExtendedLinearAddressRecord(str, blockStartAddress,
          startCode: startCode);
    }
    lastBlockAddress = blockStartAddress;
    createDataRecord(str, dataStartAddress & 0xFFFF,
        seg.slice(i, min(i + lineLength, seg.length)),
        startCode: startCode);
  }
}

/// Verifies that the line length is correct. Throws an exception otherwise.
void _validateLineLength(int len) {
  if (len > 255) {
    throw IHexValueError("Lines cannot be longer than 255 bytes! Got $len");
  }
  if (len < 1) {
    throw IHexValueError("Lines cannot be shorter than 1 byte! Got $len");
  }
}
