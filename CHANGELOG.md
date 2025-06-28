## 1.3.0

- Improved performance when parsing files or when converting segments to a string by about 400x.

## 1.2.1

- Added an example on how to convert an Intel Hex file to binary

## 1.2.0

- The Memory Segment class and the segments container were separated from the intel hex file code.
  The memory segments can be reused for other tasks.
- The checksum methods are now exported.

## 1.1.1

- Removed unused import.

## 1.1.0

- Added check for duplicate addresses when parsing a string.
- Added a method to get a ByteData object from the underlying buffer of a segment to simplify deserializing data.
- Added methods to append typed data to a memory segment.
- Added a check in toFileContents() to search for overlapping addresses.
- Management of the memory segments has been moved to its own class.

## 1.0.0

- Initial version.
- Support for Intel HEX files with all standard records and a configurable start code added.
