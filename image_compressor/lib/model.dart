part of 'compression.dart';

class CompressedImage {
  /// Model class that obtains the properties of compressed Image.
  CompressedImage(
      {required this.image,
      required this.imageSizeInBytes,
      required this.height,
      required this.width});

  /// image `String` contains the compressed image,
  final String image;

  /// imageSizeInKb `int` containes the compressed image size in bytes,
  final int imageSizeInBytes;

  /// height `int` contains the height of the compressed image,
  final int height;

  /// width `int` contains the width of the compressed image.
  final int width;
}
