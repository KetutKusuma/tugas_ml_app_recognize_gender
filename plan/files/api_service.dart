// // lib/services/api_service.dart
// // ─────────────────────────────────────────────────────────────
// // Kirim file .wav ke FastAPI /predict
// // ─────────────────────────────────────────────────────────────

// import 'dart:io';
// import 'package:dio/dio.dart';

// class PredictionResult {
//   final String prediction;
//   final List<double> probability;
//   final List<String> classes;
//   final String filename;

//   const PredictionResult({
//     required this.prediction,
//     required this.probability,
//     required this.classes,
//     required this.filename,
//   });

//   // Probabilitas tertinggi (confidence)
//   double get confidence {
//     if (probability.isEmpty) return 0;
//     return probability.reduce((a, b) => a > b ? a : b);
//   }

//   // Index kelas dengan probabilitas tertinggi
//   int get topIndex => probability.indexOf(confidence);

//   factory PredictionResult.fromJson(Map<String, dynamic> json) {
//     final data = json['data'] as Map<String, dynamic>;
//     return PredictionResult(
//       prediction  : data['prediction'] as String,
//       probability : (data['probability'] as List).map((e) => (e as num).toDouble()).toList(),
//       classes     : (data['classes']     as List).map((e) => e.toString()).toList(),
//       filename    : data['filename']     as String,
//     );
//   }
// }

// class ApiService {
//   // ⚠️  Ganti dengan IP server Anda jika test di device fisik
//   //     Emulator Android   : http://10.0.2.2:8000
//   //     Device fisik / iOS : http://<IP_LAN_ANDA>:8000
//   //     Localhost (web)    : http://127.0.0.1:8000
//   static const String _baseUrl = 'http://10.0.2.2:8000';

//   final Dio _dio = Dio(BaseOptions(
//     baseUrl        : _baseUrl,
//     connectTimeout : const Duration(seconds: 15),
//     receiveTimeout : const Duration(seconds: 30),
//   ));

//   // ── Kirim .wav → dapat prediksi ───────────────────────
//   Future<PredictionResult> predict(String wavPath) async {
//     final file = File(wavPath);
//     if (!file.existsSync()) {
//       throw Exception('File tidak ditemukan: $wavPath');
//     }

//     final formData = FormData.fromMap({
//       'file': await MultipartFile.fromFile(
//         wavPath,
//         filename: 'audio.wav',
//       ),
//     });

//     final response = await _dio.post('/predict', data: formData);

//     if (response.statusCode == 200) {
//       return PredictionResult.fromJson(response.data as Map<String, dynamic>);
//     } else {
//       final msg = (response.data as Map?)?['message'] ?? 'Unknown error';
//       throw Exception('Server error ${response.statusCode}: $msg');
//     }
//   }

//   // ── Health check ──────────────────────────────────────
//   Future<bool> isServerReady() async {
//     try {
//       final response = await _dio.get('/health');
//       return response.statusCode == 200 &&
//              (response.data['data']?['model'] == true);
//     } catch (_) {
//       return false;
//     }
//   }
// }
