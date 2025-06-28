// Copyright (C) 2022 by domohuhn
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:intel_hex/src/exceptions.dart';

void validateAddressAndLength(int address, int length) {
  if (address < 0 || length < 0 || (address + length) >= 4294967296) {
    throw IHexRangeError(
        "Address and length must be positive and less than 2^32! Got address $address + length $length");
  }
}
