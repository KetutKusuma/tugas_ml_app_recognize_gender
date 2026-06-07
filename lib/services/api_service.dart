// lib/services/api_service.dart

import 'dart:io';
import 'package:dio/dio.dart';

class PredictionResult {
  final String prediction;
  final List<double> probability;
  final List<String> classes;
  final String filename;

  const PredictionResult({
    required this.prediction,
    required this.probability,
    required this.classes,
    required this.filename,
  });

  String get gender => prediction.toString() == '0' ? 'Female' : 'Male';
  String genderFromLabel(String label) {
    switch (label.toLowerCase()) {
      case '0':
        return 'Female';
      case '1':
        return 'Male';
      default:
        return 'Unknown';
    }
  }

  double get confidence {
    if (probability.isEmpty) return 0;
    return probability.reduce((a, b) => a > b ? a : b);
  }

  int get topIndex => probability.indexOf(confidence);

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return PredictionResult(
      prediction: data['prediction'] as String,
      probability: (data['probability'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      classes: (data['classes'] as List).map((e) => e.toString()).toList(),
      filename: data['filename'] as String,
    );
  }
}

class ApiService {
  // URL bisa diubah saat runtime lewat setBaseUrl()
  String _baseUrl = 'https://audio-recognition-gender.onrender.com';

  late Dio _dio;

  ApiService() {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  String get baseUrl => _baseUrl;

  // Ubah URL dan reinit Dio
  void setBaseUrl(String url) {
    _baseUrl = url.trimRight().replaceAll(
      RegExp(r'/$'),
      '',
    ); // hapus trailing slash
    _initDio();
  }

  Future<PredictionResult> predict(String wavPath) async {
    final file = File(wavPath);
    if (!file.existsSync()) throw Exception('File tidak ditemukan: $wavPath');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(wavPath, filename: 'audio.wav'),
    });

    final response = await _dio.post('/predict', data: formData);

    if (response.statusCode == 200) {
      return PredictionResult.fromJson(response.data as Map<String, dynamic>);
    } else {
      final msg = (response.data as Map?)?['message'] ?? 'Unknown error';
      throw Exception('Server error ${response.statusCode}: $msg');
    }
  }

  Future<bool> isServerReady() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200 &&
          (response.data['data']?['model'] == true);
    } catch (_) {
      return false;
    }
  }
}
