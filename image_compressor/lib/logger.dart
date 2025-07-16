import 'package:flutter/foundation.dart';

class Logger {
  static void inform(String message) {
    if (kDebugMode) {
      debugPrint('\x1B[31m[COMPRESSOR]\x1B[0m  \x1B[36m$message\x1B[0m');
    }
  }

  static void warn(String warning) {
    if (kDebugMode) {
      print(('\x1B[31m[COMPRESSOR]\x1B[0m  \x1B[33m$warning\x1B[0m'));
    }
  }
}
