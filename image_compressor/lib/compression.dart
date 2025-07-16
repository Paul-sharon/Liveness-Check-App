import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data' as type_data;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:ui' as ui;
import 'logger.dart' as informer;
import 'package:image/image.dart' as IMG;

part 'exception.dart';
part 'fallbackmode.dart';
part 'model.dart';

class ImageCompressor {
  /// Util class that provides methods to compress image.
  ImageCompressor({
    required this.imagesizeLimitInKb,
    required this.targetDimensionsLimit,
    this.compressionFallback = FallbackMode.allow,
    this.resizeFallback = FallbackMode.deny,
  });

  /// imagesizeLimitInKb `double` is the limit to wich the image is compressed.
  final double imagesizeLimitInKb;

  /// targetDimensionsLimit `int` is the limit to which the height and width of the image is reduced.
  final int targetDimensionsLimit;

  /// compressionFallback `FallbackMode` defines the method behaviour when
  /// the compression fails to compress the image down to the limit.
  final FallbackMode compressionFallback;

  /// dimensionsReductionFallback `FallbackMode` defines the method behaviour when
  /// dimensions reduction fails to reduce the hight and width down to the given limit.
  /// FallbackMode.allow can return an image with a hight to width ratio
  /// different from the original image.
  final FallbackMode resizeFallback;

  /// Compress the given imageFile `File` and returns a `CompressedImage?` containing compressed image in `String` format
  /// and it's properties like size,height,width.
  ///
  /// if for any reason the compression fails with an exception, no object will be returned.
  /// the result can potentially be null.
  Future<CompressedImage?> compressFile({required File imageSource}) async {
    late final File soureFile;
    try {
      soureFile = await FlutterExifRotation.rotateImage(path: imageSource.path);
      return await _compress(imageSource: await soureFile.readAsBytes());
    } on ImageCompressionException catch (error, stack) {
      log("ImageCompressionException occurred while compressing image",
          error: error.toString(), stackTrace: stack);
      rethrow;
    } catch (error, stack) {
      log("Error occurred while compressing image",
          error: error, stackTrace: stack);
      throw ImageCompressionException(
        message:
            "Something went wrong while compressing image, please try again",
        error: error.toString(),
      );
    } finally {
      try {
        if (await soureFile.exists()) {
          await soureFile.delete();
          informer.Logger.inform("removed source image");
        }
      } on FileSystemException catch (error) {
        log("FileSystemException occurred while removing unused files",
            error: error.toString());
      } catch (error) {
        log("Error occurred while removing unused files",
            error: error.toString());
      }
    }
  }

  /// Compress the given imageBytes `Uint8List` and returns a `CompressedImage?` containing compressed image in `String` format
  /// and it's properties like size,height,width.
  ///
  /// if for any reason the compression fails with an exception, no object will be returned.
  /// the result can potentially be null.
  Future<CompressedImage?> compressBytes(
      {required type_data.Uint8List imageSource}) async {
    try {
      return await _compress(imageSource: imageSource);
    } on ImageCompressionException catch (error, stack) {
      log("ImageCompressionException occurred while compressing image",
          error: error.toString(), stackTrace: stack);
      rethrow;
    } catch (error, stack) {
      log("Error occurred while compressing image",
          error: error, stackTrace: stack);
      throw ImageCompressionException(
        message:
            "Something went wrong while compressing image, please try again",
        error: error.toString(),
      );
    }
  }

  Future<CompressedImage?> _compress(
      {required type_data.Uint8List imageSource}) async {
    try {
      type_data.Uint8List imageBytes = imageSource;

      ui.Image decodedImage = await material.decodeImageFromList(imageSource);

      informer.Logger.inform("Image properties before compression");
      informer.Logger.inform("Size in kb = ${imageBytes.lengthInBytes / 1024}");
      informer.Logger.inform("Height = ${decodedImage.height}");
      informer.Logger.inform("Width = ${decodedImage.width}");

      if ((decodedImage.height > targetDimensionsLimit) ||
          decodedImage.width > targetDimensionsLimit) {
        informer.Logger.warn('------------------------------');
        informer.Logger.inform("Running resize");

        List<int> dimensionsList = _getTargetDimensions(
            height: decodedImage.height, width: decodedImage.width);

        imageBytes = await compute<Uint8List, Uint8List>((imageBytes) {
          IMG.Image? image = IMG.decodeImage(imageBytes);
          IMG.Image resizedImage = IMG.copyResize(image!,
              width: dimensionsList[1],
              height: dimensionsList[0],
              interpolation: IMG.Interpolation.average);
          return Uint8List.fromList(IMG.encodePng(resizedImage));
        }, imageBytes);
        // imageBytes = await _compressImage(
        //     sourceImageBytes: imageBytes,
        //     compressionProfile: 100,
        //     targetHeight: decodedImage.height,
        //     targetWidth: decodedImage.width);

        decodedImage = await material.decodeImageFromList(imageBytes);
        informer.Logger.warn('------------------------------');
        informer.Logger.inform("Image properties after resizing");
        informer.Logger.inform(
            "Size in kb = ${imageBytes.lengthInBytes / 1024}");
        informer.Logger.inform("Height = ${decodedImage.height}");
        informer.Logger.inform("Width = ${decodedImage.width}");
      }

      if (imageBytes.lengthInBytes / 1024 > imagesizeLimitInKb) {
        informer.Logger.warn('------------------------------');
        informer.Logger.inform("Running compression");

        imageBytes = await _startImageCompression(
          imageBytes: imageBytes,
          height: decodedImage.height,
          width: decodedImage.width,
          imageSizeLimitINkB: imagesizeLimitInKb,
        );

        decodedImage = await material.decodeImageFromList(imageBytes);
      }

      informer.Logger.warn('------------------------------');
      informer.Logger.inform("Image properties after compression");
      informer.Logger.inform("Size in kb = ${imageBytes.lengthInBytes / 1024}");
      informer.Logger.inform("Height = ${decodedImage.height}");
      informer.Logger.inform("Width = ${decodedImage.width}");

      return CompressedImage(
          image: base64Encode(imageBytes),
          imageSizeInBytes: imageBytes.lengthInBytes,
          height: decodedImage.height,
          width: decodedImage.width);
    } catch (error, stackTrace) {
      log("compression", error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  int _calculateDivisionFactor({required int height, required int width}) {
    if (height == 0) {
      informer.Logger.inform("gcd: $width");

      return width;
    }

    return _calculateDivisionFactor(height: width % height, width: height);
  }

  List<int> _calculateAllDivisibleFactors({required int gcd}) {
    List<int> divisibleFactors = [];
    for (int i = 1; i <= gcd; i++) {
      if (gcd % i == 0) {
        divisibleFactors.add(i);
      }
    }
    return divisibleFactors;
  }

  int _calculatePreciseDivisionFactor({
    required List<int> divisibleFactors,
    required int height,
    required int width,
  }) {
    for (int i = 1; i < divisibleFactors.length; i++) {
      if ((height / divisibleFactors[i] <= targetDimensionsLimit &&
              height / divisibleFactors[i] >= 200) &&
          (width / divisibleFactors[i] <= targetDimensionsLimit &&
              width / divisibleFactors[i] >= 200)) {
        informer.Logger.inform("division factor: ${divisibleFactors[i]}");
        return divisibleFactors[i];
      }
    }

    if (resizeFallback == FallbackMode.allow) {
      for (int i = 2; i <= 5; i++) {
        if ((height / i <= targetDimensionsLimit && height / i >= 200) &&
            (width / i <= targetDimensionsLimit && width / i >= 200)) {
          informer.Logger.warn(
              "No precise division factor available, proceeding with division factor $i");
          return i;
        }
      }
      informer.Logger.warn(
          "No precise division factor available, proceeding with default division factor 1");
      return 1;
    } else {
      throw ImageCompressionException(
          message:
              "Unable to reduce image height and width, please try cropping the image");
    }
  }

  List<int> _getTargetDimensions({required int height, required int width}) {
    if (height > width) {
      double quotient = height / width;
      int returnHeight = targetDimensionsLimit;
      int returnWidth = returnHeight ~/ quotient;
      return [returnHeight, returnWidth];
    } else {
      double quotient = width / height;
      int returnWidth = targetDimensionsLimit;
      int returnHeight = returnWidth ~/ quotient;
      return [returnHeight, returnWidth];
    }
  }

  Future<type_data.Uint8List> _startImageCompression({
    required type_data.Uint8List imageBytes,
    required imageSizeLimitINkB,
    required int height,
    required int width,
  }) async {
    type_data.Uint8List compressedImageBytes = imageBytes;
    for (int i = 99; i >= 30; i--) {
      if ((compressedImageBytes.lengthInBytes / 1024) > imageSizeLimitINkB) {
        compressedImageBytes = await _compressImage(
            sourceImageBytes: imageBytes,
            compressionProfile: i,
            targetHeight: height,
            targetWidth: width);
      } else {
        informer.Logger.inform('Compressed with profile [$i]');
        return compressedImageBytes;
      }
    }

    if (compressionFallback == FallbackMode.deny) {
      throw ImageCompressionException(
          message:
              "Unable to compress Image, Please select an image of smaller size or crop the image appropriately");
    } else {
      informer.Logger.warn(
          "Failed to compress image to the given limit, proceeding with lowest possible size");
      return compressedImageBytes;
    }
  }

  Future<type_data.Uint8List> _compressImage({
    required type_data.Uint8List sourceImageBytes,
    required int compressionProfile,
    required int targetHeight,
    required targetWidth,
  }) async {
    final type_data.Uint8List compressedImageBytes =
        await FlutterImageCompress.compressWithList(
      sourceImageBytes,
      autoCorrectionAngle: false,
      format: CompressFormat.jpeg,
      inSampleSize: 1,
      keepExif: false,
      minHeight: targetHeight,
      minWidth: targetWidth,
      quality: compressionProfile,
    ).catchError((error, stack) {
      informer.Logger.inform("Error");
      throw error;
    });
    return compressedImageBytes;
  }
}
