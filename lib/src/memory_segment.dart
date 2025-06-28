// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:typed_data';
import 'dart:math';
import 'package:intel_hex/src/exceptions.dart';
import 'package:intel_hex/src/validation.dart';

/// The class that represents a memory segment of an Intel Hex file.
///
/// A segment consists of a start address and a contiguous block of bytes.
class MemorySegment extends Iterable<SegmentByte> {
  /// Constructs a segment at the given [address] with the given [length].
  MemorySegment({required int address, int length = 0})
      : _startAddress = address,
        _data = Uint8List(length) {
    validateAddressAndLength(address, length);
  }

  /// Constructs a segment at the given [address] with the given [data].
  MemorySegment.fromBytes({required int address, required Iterable<int> data})
      : _startAddress = address {
    validateAddressAndLength(address, data.length);
    appendAll(data);
  }

  /// the start address of the segment.
  int _startAddress = 0;

  /// If this segment overlaps another one - for internal use in the container.
  bool isOverlapping = false;

  Uint8List _data = Uint8List(0);

  /// Returns a view into the internal data.
  Uint8List slice([int start = 0, int? end]) {
    return Uint8List.sublistView(_data, start, end);
  }

  /// Returns the first valid address for this segment.
  int get address => _startAddress;

  /// Returns one past the last valid address for this segment.
  int get endAddress => _startAddress + length;

  /// Get a ByteData object from the underlying buffer. Allows to serialize/deserialize values.
  ByteData get byteData => ByteData.sublistView(_data);

  /// The number of bytes inside the segment.
  @override
  int get length => _data.length;

  /// Checks if [size] bytes can be read from [position] in this segment.
  /// [position] is an absolute address.
  bool isInRange(int position, int size) {
    validateAddressAndLength(position, length);
    return _startAddress <= position && position + size <= endAddress;
  }

  /// Checks if two segments are overlapping / can be combined without a gap.
  bool overlaps(MemorySegment other) {
    return address <= other.endAddress && other.address <= endAddress;
  }

  @override
  Iterator<SegmentByte> get iterator => SegmentIterator(this);

  /// Gets the value at [position].
  /// [position] is an absolute address.
  /// May throw an exception if the position is out of range.
  int byte(int position) {
    validateAddressAndLength(position, 1);
    if (isInRange(position, 1)) {
      return _data[position - _startAddress];
    }
    throw IHexRangeError(
        "Address $position is out of range [$_startAddress, ${_startAddress + length}]");
  }

  /// Fills the complete segment with [value].
  void fill(int value) {
    for (int i = 0; i < _data.length; ++i) {
      _data[i] = value;
    }
  }

  /// Resizes the segment to start at the new address [newAddress] with the given length [newLength].
  /// The contents of the old segment are preserved at the same addresses, if they are still in range of the
  /// new segment.
  void resize(int newAddress, int newLength) {
    validateAddressAndLength(newAddress, newLength);
    final next = Uint8List(newLength);
    final writeOffset =
        newAddress < _startAddress ? _startAddress - newAddress : 0;
    final readOffset =
        newAddress > _startAddress ? newAddress - _startAddress : 0;
    final maxWrite = length > writeOffset ? newLength - writeOffset : 0;
    final copyLen =
        length > readOffset ? min(length - readOffset, maxWrite) : 0;
    for (int i = 0; i < copyLen; ++i) {
      next[i + writeOffset] = _data[i + readOffset];
    }
    _startAddress = newAddress;
    _data = next;
  }

  /// Appends a [byte] at the end.
  void append(int byte) {
    resize(address, length + 1);
    _data.last = byte;
  }

  /// Appends [bytes] at the end.
  void appendAll(Iterable<int> bytes) {
    var old = length;
    resize(address, length + bytes.length);
    for (int i = 0; i < bytes.length; ++i) {
      _data[i + old] = bytes.elementAt(i);
    }
  }

  /// Modifies a byte already present in the segment.
  void writeByte(int position, int byte) {
    if (!isInRange(position, 1)) {
      throw IHexRangeError(
          "Address $position is out of range [$_startAddress, ${_startAddress + length}]");
    }
    var offset = position - _startAddress;
    _data[offset] = byte;
  }

  /// Writes a list of bytes to a range present in the segment.
  void writeBytes(int position, Iterable<int> bytes) {
    if (!isInRange(position, bytes.length)) {
      throw IHexRangeError(
          "Address [$position, ${position + bytes.length}] is out of range [$_startAddress, ${_startAddress + length}]");
    }
    var offset = position - _startAddress;
    for (final byte in bytes) {
      _data[offset] = byte;
      offset += 1;
    }
  }

  /// Appends a [value] at the end of the buffer. length increases by 4 bytes.
  /// The value is serialized to the given [endian] format.
  void appendFloat32(double value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 4);
    byteData.setFloat32(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 8 bytes.
  /// The value is serialized to the given [endian] format.
  void appendFloat64(double value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 8);
    byteData.setFloat64(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 1 byte.
  void appendInt8(int value) {
    final old = length;
    resize(address, old + 1);
    byteData.setInt8(old, value);
  }

  /// Appends a [value] at the end of the buffer. length increases by 2 bytes.
  /// The value is serialized to the given [endian] format.
  void appendInt16(int value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 2);
    byteData.setInt16(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 4 bytes.
  /// The value is serialized to the given [endian] format.
  void appendInt32(int value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 4);
    byteData.setInt32(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 8 bytes.
  /// The value is serialized to the given [endian] format.
  void appendInt64(int value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 8);
    byteData.setInt64(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 1 byte.
  void appendUint8(int value) {
    final old = length;
    resize(address, old + 1);
    byteData.setUint8(old, value);
  }

  /// Appends a [value] at the end of the buffer. length increases by 2 bytes.
  /// The value is serialized to the given [endian] format.
  void appendUint16(int value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 2);
    byteData.setUint16(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 4 bytes.
  /// The value is serialized to the given [endian] format.
  void appendUint32(int value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 4);
    byteData.setUint32(old, value, endian);
  }

  /// Appends a [value] at the end of the buffer. length increases by 8 bytes.
  /// The value is serialized to the given [endian] format.
  void appendUint64(int value, [Endian endian = Endian.little]) {
    final old = length;
    resize(address, old + 8);
    byteData.setUint64(old, value, endian);
  }

  /// Combines this segment with the other segment.
  /// The data from the [other] segment will overwrite overlapping data in this segment.
  void combine(MemorySegment other) {
    if (other == this) {
      return;
    }
    final nextAddress = min(address, other.address);
    final combinedLen = max(endAddress, other.endAddress) - nextAddress;
    final nextEnd = nextAddress + combinedLen;
    if (_startAddress > nextAddress || nextEnd > endAddress) {
      resize(nextAddress, combinedLen);
    }
    writeBytes(other.address, other.slice());
  }
}

/// Wrapper for the return value of the iterator.
class SegmentByte {
  /// The address of the byte
  final int address;

  /// The value of the byte
  final int value;
  SegmentByte(this.address, this.value);
}

/// Iterator for all mutations in a given text.
class SegmentIterator implements Iterator<SegmentByte> {
  SegmentIterator(this.segment);

  final MemorySegment segment;
  int _position = 0;
  bool _initialized = false;

  @override
  SegmentByte get current {
    if (_initialized && _position < segment.length) {
      int position = segment.address + _position;
      return SegmentByte(position, segment.byte(position));
    } else {
      throw IHexValueError(
          "The iterator was either not initialized ($_initialized) or is past its last element! ($_position < max: ${segment.length})");
    }
  }

  @override
  bool moveNext() {
    if (!_initialized) {
      _initialized = true;
      _position = 0;
    } else {
      _position++;
    }
    return _position < segment.length;
  }
}
