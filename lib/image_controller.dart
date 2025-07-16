import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageController {
  static Future<Map<String, dynamic>> sendImage(File imageFile) async {
    final firstUri =
        Uri.parse('http://192.168.104.235:8080/api/verify-liveness');
    final secondUri = Uri.parse('http://192.168.104.235:8000/detect-spoof');
    try {
      final firstRequest = http.MultipartRequest('POST', firstUri)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final firstResponse = await firstRequest.send();
      final firstRespStr = await firstResponse.stream.bytesToString();
      bool livenessTrue = false;
      try {
        final jsonData = jsonDecode(firstRespStr);
        livenessTrue = jsonData['liveness'] == true;
      } catch (e) {
        livenessTrue = false;
      }
      if (livenessTrue) {
        final secondRequest = http.MultipartRequest('POST', secondUri)
          ..files
              .add(await http.MultipartFile.fromPath('file', imageFile.path));
        final secondResponse = await secondRequest.send();
        final secondRespStr = await secondResponse.stream.bytesToString();
        return {
          'first': firstRespStr,
          'second': secondResponse.statusCode == 200 ? secondRespStr : null,
          'firstStatus': firstResponse.statusCode,
          'secondStatus': secondResponse.statusCode,
        };
      } else {
        return {
          'first': firstRespStr,
          'second': null,
          'firstStatus': firstResponse.statusCode,
          'secondStatus': null,
        };
      }
    } catch (e) {
      return {
        'first': null,
        'second': null,
        'firstStatus': null,
        'secondStatus': null,
        'error': e.toString(),
      };
    }
  }
}
