// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

/// This library provides the functionality to read and write Intel HEX files.
///
/// Intel HEX is a file format that stores binary data as ASCII text files.
/// The primary interface to use this library is the class [IntelHexFile].
/// The hex file may contain multiple instances of [MemorySegment] that
/// describe the binary layout of the memory. The segments are managed via
/// the base class of the file: [MemorySegmentContainer].
library;

export 'src/intel_hex_base.dart';
export 'src/memory_segment.dart';
export 'src/memory_segment_container.dart';
export 'src/checksum.dart';
