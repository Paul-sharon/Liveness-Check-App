part of 'compression.dart';

class ImageCompressionException implements Exception {
  /// Exception class that is raised if an error occurres while compressing the image.
  ImageCompressionException({required this.message, this.error});

  /// message `String`, a user readable message that is provided when the expetion is thrown,
  final String message;

  /// error `String?`, the String representation of an exception class that actually raised the exception.
  /// error is not provided unless the exception was raised from a catch block.
  final String? error;

  @override
  String toString() {
    String convertable = "message:$message";
    if (error != null) {
      convertable = "$convertable, error:$error";
    }
    return convertable;
  }
}
