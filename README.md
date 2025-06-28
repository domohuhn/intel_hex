# Intel HEX library

[![Dart](https://github.com/domohuhn/intel_hex/actions/workflows/dart.yml/badge.svg)](https://github.com/domohuhn/intel_hex/actions/workflows/dart.yml)
[![codecov](https://codecov.io/gh/domohuhn/intel_hex/branch/main/graph/badge.svg?token=KEN97CAD5L)](https://codecov.io/gh/domohuhn/intel_hex)

A dart library that reads and writes [Intel HEX files](https://en.wikipedia.org/wiki/Intel_HEX).
Intel HEX is a file format that is used to store binary data as ASCII text. It is often used
to program microcontrollers. The file format comprises of record blocks. Each record block is represented as a line in
the text file. A record starts with a ":" character and ends at the end of the line. The last
byte of a record block is the checksum of all other bytes in this block.

A record has six fields:

  - Start code. Usually ":".
  - Byte count
  - Address
  - Record type
  - Data. May be empty.
  - Checksum.

## Features

This library supports both reading and writing Intel HEX files.
Any comments in the files (or leading characters, empty lines) are ignored.
Line lengths from 1 to 255 bytes are supported.

The following record types can be parsed:

| Record type     | Id   | Description |
| ---------   | -------------------------------  | ----------- |
| Data | 00 | A data field with the contents of the file. |
| End Of File  | 01 | The parser stops once an End Of File record is found. |
| Extended Segment Address | 02 | A data field with an extended address that is added to the address all following data records. Allows addressing up to 1 MB. |
| Start Segment Address  | 03 | A data field that holds the initial instruction pointer for 80x86 CPUs. |
| Extended Linear Address | 04 | A data field that contains the upper 16 bits of the addresses for all subsequent data fields. Allows using up to 4 GB. |
| Start Linear Address  | 05 | Starting execution address for CPUs that support it. |

## Getting started

To use the package, simply add it to your pubspec.yaml:
```yaml
dependencies:
  intel_hex: ^1.3.0
```

And you are good to go!

## Usage

Here is a simple example showing how to read a file:

```dart
import 'package:intel_hex/intel_hex.dart';

// example reading a file ...
final file = File(path).readAsStringSync();
var hex = IntelHexFile.fromString(file);
```

Converting binary data to an Intel HEX string can be done with the following code:
```dart
import 'package:intel_hex/intel_hex.dart';

Uint8List data = /* get binary data */;
var hex = IntelHexFile.fromData(data);
var hexString = hex.toFileContents();
```

See also the examples in the [examples directory](https://github.com/domohuhn/intel_hex/tree/main/example).
There is also an up to date documentation on [pub.dev](https://pub.dev/documentation/intel_hex/latest/) that explains the API of the library.

## Additional information

If there are any bugs or you need an additional feature, please report them in the [issue tracker](https://github.com/domohuhn/intel_hex/issues).
