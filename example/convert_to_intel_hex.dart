// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:intel_hex/intel_hex.dart';
import 'dart:io';
import 'dart:typed_data';

/// This file shows how to create a program that reads a file
/// from the file system and converts it to an Intel HEX file.
/// The output file will be called &lt;path&gt;.hex.

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print(
        "Intel HEX file converter. This program will read a file and convert it to an Intel HEX file.\n    Usage: convert_to_intel_hex <path to file>\n\nThe output file will have the same name as the input, but with an additional .hex appended to its path.");
    exit(0);
  }
  Uint8List file = Uint8List(0);
  String path = arguments[0];
  try {
    file = File(path).readAsBytesSync();
  } catch (e) {
    print("Failed to open file '$path':\n$e");
    exit(1);
  }
  try {
    var hex = IntelHexFile.fromData(file);
    var out = File("$path.hex");
    if (out.existsSync()) {
      print("ERROR: '$path.hex' alread exists!");
      exit(1);
    }
    out.writeAsStringSync(hex.toFileContents());
    print('Created "$path.hex"');
  } catch (e) {
    print("ERROR: '$path' could not be converted!\n$e");
    exit(1);
  }
}
