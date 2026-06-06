// // lib/services/audio_service.dart
// // ─────────────────────────────────────────────────────────────
// // Mengelola semua operasi audio:
// //   - Rekam dari mic (maks 3 detik, otomatis stop)
// //   - Ambil file dari storage
// //   - Trim ke 3 detik via FFmpeg
// //   - Konversi ke WAV 16kHz mono via FFmpeg
// // ─────────────────────────────────────────────────────────────

// import 'dart:io';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_min/return_code.dart';

// class AudioService {
//   static const int maxDurationSec = 3;

//   final AudioRecorder _recorder = AudioRecorder();

//   // ── Cek izin mikrofon ──────────────────────────────────
//   Future<bool> hasPermission() async {
//     return await _recorder.hasPermission();
//   }

//   // ─────────────────────────────────────────────────────────
//   // REKAM dari mikrofon
//   // Otomatis berhenti setelah 3 detik
//   // Return: path file .wav hasil rekaman
//   // ─────────────────────────────────────────────────────────
//   Future<String?> recordFromMic({
//     void Function(int seconds)? onTick,
//   }) async {
//     if (!await hasPermission()) return null;

//     final dir      = await getTemporaryDirectory();
//     final rawPath  = p.join(dir.path, 'rec_raw_${DateTime.now().millisecondsSinceEpoch}.m4a');
//     final wavPath  = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');

//     // Mulai rekam
//     await _recorder.start(
//       const RecordConfig(
//         encoder    : AudioEncoder.aacLc,   // rekam dulu ke m4a (stabil di iOS/Android)
//         sampleRate : 16000,
//         numChannels: 1,
//       ),
//       path: rawPath,
//     );

//     // Hitung mundur 3 detik
//     for (int i = 1; i <= maxDurationSec; i++) {
//       await Future.delayed(const Duration(seconds: 1));
//       onTick?.call(i);
//     }

//     await _recorder.stop();

//     // Konversi m4a → wav 16kHz mono via FFmpeg
//     final result = await FFmpegKit.execute(
//       '-y -i "$rawPath" -ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"',
//     );
//     final rc = await result.getReturnCode();

//     // Hapus file raw
//     if (File(rawPath).existsSync()) File(rawPath).deleteSync();

//     if (ReturnCode.isSuccess(rc)) return wavPath;
//     return null;
//   }

//   Future<void> stopRecording() async {
//     if (await _recorder.isRecording()) {
//       await _recorder.stop();
//     }
//   }

//   // ─────────────────────────────────────────────────────────
//   // AMBIL dari file picker
//   // Jika durasi > 3 detik → crop bagian tengah ke 3 detik
//   // Return: path file .wav siap kirim
//   // ─────────────────────────────────────────────────────────
//   Future<String?> pickAndProcessFile() async {
//     final result = await FilePicker.platform.pickFiles(
//       type           : FileType.audio,
//       allowMultiple  : false,
//     );

//     if (result == null || result.files.isEmpty) return null;
//     final sourcePath = result.files.single.path!;

//     final dir     = await getTemporaryDirectory();
//     final wavPath = p.join(dir.path, 'pick_${DateTime.now().millisecondsSinceEpoch}.wav');

//     // Dapatkan durasi file
//     final duration = await _getAudioDuration(sourcePath);

//     String ffmpegCmd;
//     if (duration != null && duration > maxDurationSec) {
//       // Crop bagian tengah ke 3 detik (sama dengan logika Python)
//       final start = (duration - maxDurationSec) / 2;
//       ffmpegCmd =
//         '-y -i "$sourcePath" -ss $start -t $maxDurationSec '
//         '-ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"';
//     } else {
//       // Durasi ≤ 3 detik, konversi saja ke wav 16kHz mono
//       ffmpegCmd =
//         '-y -i "$sourcePath" -ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"';
//     }

//     final execResult = await FFmpegKit.execute(ffmpegCmd);
//     final rc         = await execResult.getReturnCode();

//     if (ReturnCode.isSuccess(rc)) return wavPath;
//     return null;
//   }

//   // ── Dapatkan durasi audio (detik) via FFprobe ──────────
//   Future<double?> _getAudioDuration(String filePath) async {
//     try {
//       final session = await FFmpegKit.execute(
//         '-i "$filePath" 2>&1 | grep Duration',
//       );
//       final output = await session.getOutput();
//       if (output == null) return null;

//       // Parse "Duration: 00:00:05.23"
//       final match = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.?\d*)').firstMatch(output);
//       if (match == null) return null;

//       final h = int.parse(match.group(1)!);
//       final m = int.parse(match.group(2)!);
//       final s = double.parse(match.group(3)!);
//       return h * 3600 + m * 60 + s;
//     } catch (_) {
//       return null;
//     }
//   }

//   void dispose() {
//     _recorder.dispose();
//   }
// }
