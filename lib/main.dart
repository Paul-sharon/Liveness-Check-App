import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_compressor/compression.dart';
import 'package:image_picker/image_picker.dart';
import 'image_controller.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liveness-Check App ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String? _errorMessage;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;
  bool _isCompressing = false;
  String? _resultMessage;

  Future<void> _captureImage() async {
    try {
      setState(() {
        _isCompressing = true;
        _errorMessage = null;
      });
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        setState(() {
          _errorMessage = 'No image captured.';
          _isCompressing = false;
        });
        return;
      }
      File preCompressed = File(photo.path);
      ImageCompressor compressor = ImageCompressor(
          imagesizeLimitInKb: 4000, targetDimensionsLimit: 1500);
      final response =
          await compressor.compressFile(imageSource: preCompressed);
      if (response == null) {
        setState(() {
          _errorMessage = 'Image compression failed.';
          _isCompressing = false;
        });
        return;
      }
      // Save compressed image to a new file
      final compressedBytes = base64Decode(response.image);
      final compressedPath = photo.path.replaceFirst(
        RegExp(r'(\.jpg|\.jpeg|\.png)\$'),
        '_compressed.jpg',
      );
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes, mode: FileMode.write);
      setState(() {
        _imageFile = compressedFile;
        _isCompressing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture image: ${e.toString()}';
        _isCompressing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Liveness Check',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: Colors.white,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 240,
                  height: 240,
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      if (_isCompressing)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 18),
                            Text('Image is processing...',
                                style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                          ],
                        )
                      else if (_imageFile != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_imageFile!,
                              width: 220, height: 220, fit: BoxFit.cover),
                        )
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.image, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No image captured.',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      if (_imageFile != null && !_isCompressing)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  _imageFile = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.delete,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  onPressed: _captureImage,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.send),
                  label: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Send',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                  onPressed: _imageFile != null && !_isSending
                      ? () async {
                          setState(() {
                            _isSending = true;
                            _resultMessage = null;
                          });
                          try {
                            final resultMap =
                                await ImageController.sendImage(_imageFile!);
                            setState(() {
                              _isSending = false;
                              String firstMsg = '';
                              try {
                                final decoded =
                                    resultMap['first']?.trim() ?? '';
                                if (decoded.isNotEmpty &&
                                    decoded.startsWith('{')) {
                                  final data = jsonDecode(decoded);
                                  firstMsg =
                                      data['reason']?.toString() ?? decoded;
                                } else {
                                  firstMsg = decoded;
                                }
                              } catch (e) {
                                firstMsg = resultMap['first'] ?? '';
                              }

                              String secondMsg = '';
                              if (resultMap['second'] != null) {
                                try {
                                  final decoded2 = resultMap['second'].trim();
                                  if (decoded2.isNotEmpty &&
                                      decoded2.startsWith('{')) {
                                    final data2 = jsonDecode(decoded2);
                                    secondMsg = data2['message']?.toString() ??
                                        decoded2;
                                  } else {
                                    secondMsg = decoded2;
                                  }
                                } catch (e) {
                                  secondMsg = resultMap['second'] ?? '';
                                }
                              }
                              if (secondMsg.isNotEmpty) {
                                _resultMessage =
                                    'Liveness: $firstMsg\nSpoof: $secondMsg';
                              } else {
                                _resultMessage = 'Liveness: $firstMsg';
                              }
                            });
                          } catch (e) {
                            setState(() {
                              _isSending = false;
                              _resultMessage = 'Error: ${e.toString()}';
                            });
                          }
                        }
                      : null,
                ),
              ),
              if (_resultMessage != null)
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.deepPurple, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _resultMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
