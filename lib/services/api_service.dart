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
  String _baseUrl = 'https://audio-recognition-gender.onrender.com';
  late Dio _dio;

  // ── Retry config ──────────────────────────────────────
  static const int _maxRetries = 3;
  static const Duration _retryBaseDelay = Duration(seconds: 2);

  ApiService() {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        // Lebih toleran karena server di Render sering cold start (bisa 30-60 detik)
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
  }

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    _initDio();
  }

  // ── Predict dengan retry ──────────────────────────────
  // ── Predict dengan retry ──────────────────────────────
  /// [endpoint]:
  /// - '/predict-full' → Model 52 (default, lengkap: probability & classes)
  /// - '/predict'      → Model 45 (lebih ringan/cepat)
  Future<PredictionResult> predict(
    String wavPath, {
    String endpoint = '/predict-full',
  }) async {
    final file = File(wavPath);
    if (!file.existsSync()) throw Exception('File tidak ditemukan: $wavPath');

    DioException? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(wavPath, filename: 'audio.wav'),
        });

        final response = await _dio.post(endpoint, data: formData);

        if (response.statusCode == 200) {
          return PredictionResult.fromJson(
            response.data as Map<String, dynamic>,
          );
        } else {
          final msg = (response.data as Map?)?['message'] ?? 'Unknown error';
          throw Exception('Server error ${response.statusCode}: $msg');
        }
      } on DioException catch (e) {
        lastError = e;

        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError;

        if (!isRetryable || attempt == _maxRetries - 1) rethrow;

        final delay = _retryBaseDelay * (1 << attempt);
        await Future.delayed(delay);
      }
    }

    throw lastError ??
        Exception('Gagal menghubungi server setelah $_maxRetries percobaan');
  }

  // ── Health check dengan timeout pendek ───────────────
  Future<bool> isServerReady() async {
    try {
      final response = await _dio
          .get(
            '/health',
            options: Options(
              // Health check pakai timeout lebih pendek agar UI tidak hang
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
            ),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ── Tunggu server siap (untuk cold start Render) ──────
  /// Polling sampai server ready atau timeout tercapai.
  /// [onStatusUpdate] dipanggil tiap percobaan dengan pesan status.
  Future<bool> waitUntilReady({
    Duration timeout = const Duration(seconds: 90),
    Duration pollInterval = const Duration(seconds: 5),
    void Function(String message, int attempt)? onStatusUpdate,
  }) async {
    final deadline = DateTime.now().add(timeout);
    int attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      attempt++;
      onStatusUpdate?.call('Menunggu server... (percobaan $attempt)', attempt);

      final ready = await isServerReady();
      if (ready) return true;

      // Hitung sisa waktu, jangan delay lebih dari itu
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      await Future.delayed(remaining < pollInterval ? remaining : pollInterval);
    }

    return false;
  }
}
