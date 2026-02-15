import 'dart:io';

import 'package:dio/dio.dart';

import '../models/detection.dart';

/// Base URL for detection API.
/// - Emulator: http://10.0.2.2:8000
/// - Physical device: http://YOUR_LAN_IP:8000 (e.g. http://192.168.1.100:8000)
const String kDetectionBaseUrlDefault = 'http://192.168.1.72:8000';

/// Configurable base URL (no trailing slash). Override for physical device.
String detectionBaseUrl = kDetectionBaseUrlDefault;

/// POST /detect with multipart file. Timeout 30s. Returns typed response.
Future<DetectResponseModel> postDetect(File file) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  final uri = '${detectionBaseUrl.replaceAll(RegExp(r'/$'), '')}/detect';
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(
      file.path,
      filename: 'image.jpg',
    ),
  });

  final response = await dio.post<Map<String, dynamic>>(
    uri,
    data: formData,
    options: Options(
      contentType: 'multipart/form-data',
      responseType: ResponseType.json,
    ),
  );

  if (response.data == null) {
    throw Exception('Empty response from server');
  }
  return DetectResponseModel.fromJson(response.data!);
}
