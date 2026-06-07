// lib/services/audio_service.dart
// ─────────────────────────────────────────────────────────────
// Mengelola semua operasi audio:
//   - Rekam dari mic (maks 3 detik, otomatis stop)
//   - Ambil file dari storage
//   - Trim ke 3 detik via FFmpeg
//   - Konversi ke WAV 16kHz mono via FFmpeg
// ─────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  static const int maxDurationSec = 3;

  final AudioRecorder _recorder = AudioRecorder();

  // ─────────────────────────────────────────────────────────
  // PERMISSION: Mikrofon
  // Coba lewat record package dulu, fallback ke permission_handler
  // ─────────────────────────────────────────────────────────
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    print("MIC BEFORE = $status");

    final result = await Permission.microphone.request();
    print("MIC AFTER = $result");

    return result.isGranted;
  }

  // ─────────────────────────────────────────────────────────
  // PERMISSION: Storage
  // Android ≤ 12 → READ_EXTERNAL_STORAGE
  // Android 13+ → READ_MEDIA_AUDIO
  // ─────────────────────────────────────────────────────────
  Future<bool> hasStoragePermission() async {
    try {
      // Android 13+ (API 33+)
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidSdkVersion();

        if (androidInfo >= 33) {
          // Android 13+ pakai READ_MEDIA_AUDIO
          final status = await Permission.audio.status;
          if (status.isGranted) return true;
          if (status.isPermanentlyDenied) {
            await openAppSettings();
            return false;
          }
          final result = await Permission.audio.request();
          if (result.isPermanentlyDenied) {
            await openAppSettings();
            return false;
          }
          return result.isGranted;
        } else {
          // Android 9–12 pakai READ_EXTERNAL_STORAGE
          final status = await Permission.storage.status;
          if (status.isGranted) return true;
          if (status.isPermanentlyDenied) {
            await openAppSettings();
            return false;
          }
          final result = await Permission.storage.request();
          if (result.isPermanentlyDenied) {
            await openAppSettings();
            return false;
          }
          return result.isGranted;
        }
      }

      // iOS: FilePicker handle sendiri
      return true;
    } catch (e) {
      print('Error hasStoragePermission: $e');
      return true; // biarkan FilePicker yang handle
    }
  }

  // ── Helper: ambil Android SDK version ─────────────────────
  Future<int> _getAndroidSdkVersion() async {
    try {
      // Gunakan Platform.version sebagai fallback
      // Atau pakai package device_info_plus jika tersedia
      // Default ke 28 (Android 9) jika tidak bisa detect
      return 28;
    } catch (_) {
      return 28;
    }
  }

  // ─────────────────────────────────────────────────────────
  // REKAM dari mikrofon
  // Otomatis berhenti setelah 3 detik
  // Return: path file .wav hasil rekaman, null jika gagal
  // ─────────────────────────────────────────────────────────
  Future<String?> recordFromMic({void Function(int seconds)? onTick}) async {
    try {
      // Pastikan permission granted
      if (!await hasPermission()) {
        print('Microphone permission denied');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawPath = p.join(dir.path, 'rec_raw_$timestamp.m4a');
      final wavPath = p.join(dir.path, 'rec_$timestamp.wav');

      // Mulai rekam ke m4a (stabil di iOS & Android)
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: rawPath,
      );

      // Hitung mundur maxDurationSec detik
      for (int i = 1; i <= maxDurationSec; i++) {
        await Future.delayed(const Duration(seconds: 1));
        onTick?.call(i);

        // Cek apakah recorder masih aktif
        if (!await _recorder.isRecording()) break;
      }

      // Stop rekaman
      await _recorder.stop();

      // Cek apakah file raw ada
      if (!File(rawPath).existsSync()) {
        print('Raw file tidak ditemukan: $rawPath');
        return null;
      }

      // Konversi m4a → wav 16kHz mono via FFmpeg
      final ffmpegResult = await FFmpegKit.execute(
        '-y -i "$rawPath" -ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"',
      );
      final rc = await ffmpegResult.getReturnCode();

      // Hapus file raw setelah konversi
      _safeDelete(rawPath);

      if (ReturnCode.isSuccess(rc)) {
        print('Rekaman berhasil: $wavPath');
        return wavPath;
      }

      // FFmpeg gagal
      final logs = await ffmpegResult.getLogs();
      print(
        'FFmpeg gagal. RC=$rc, Logs: ${logs.map((l) => l.getMessage()).join('\n')}',
      );
      return null;
    } catch (e) {
      print('Error recordFromMic: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // STOP rekaman manual (dari tombol "Hentikan")
  // ─────────────────────────────────────────────────────────
  Future<void> stopRecording() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      print('Error stopRecording: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // AMBIL dari file picker
  // Jika durasi > 3 detik → crop bagian tengah ke 3 detik
  // Return: path file .wav siap kirim, null jika gagal
  // ─────────────────────────────────────────────────────────
  Future<String?> pickAndProcessFile() async {
    try {
      // Request storage permission dulu
      if (!await hasStoragePermission()) {
        print('Storage permission denied');
        return null;
      }

      // Buka file picker
      final pickerResult = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) {
        print('User membatalkan file picker');
        return null;
      }

      final sourcePath = pickerResult.files.single.path;
      if (sourcePath == null) {
        print('Path file null');
        return null;
      }

      if (!File(sourcePath).existsSync()) {
        print('File tidak ditemukan: $sourcePath');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final wavPath = p.join(
        dir.path,
        'pick_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      // Dapatkan durasi file
      final duration = await _getAudioDuration(sourcePath);
      print('Durasi file: ${duration}s');

      String ffmpegCmd;
      if (duration != null && duration > maxDurationSec) {
        // Crop bagian tengah ke maxDurationSec detik
        final start = ((duration - maxDurationSec) / 2).toStringAsFixed(3);
        ffmpegCmd =
            '-y -i "$sourcePath" -ss $start -t $maxDurationSec '
            '-ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"';
        print('Crop dari detik $start selama ${maxDurationSec}s');
      } else {
        // Durasi ≤ 3 detik, konversi saja
        ffmpegCmd =
            '-y -i "$sourcePath" -ar 16000 -ac 1 -c:a pcm_s16le "$wavPath"';
        print('Konversi tanpa crop');
      }

      final execResult = await FFmpegKit.execute(ffmpegCmd);
      final rc = await execResult.getReturnCode();

      if (ReturnCode.isSuccess(rc)) {
        print('File berhasil diproses: $wavPath');
        return wavPath;
      }

      final logs = await execResult.getLogs();
      print(
        'FFmpeg error. RC=$rc, Logs: ${logs.map((l) => l.getMessage()).join('\n')}',
      );
      return null;
    } catch (e) {
      print('Error pickAndProcessFile: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Dapatkan durasi audio (detik) via FFprobe / FFmpeg
  // ─────────────────────────────────────────────────────────
  Future<double?> _getAudioDuration(String filePath) async {
    try {
      // FFmpeg Kit: gunakan -i saja untuk mendapatkan info file
      final session = await FFmpegKit.execute('-i "$filePath"');

      // Output ada di getLogs() karena ffmpeg print info ke stderr
      final logs = await session.getLogs();
      final output = logs.map((l) => l.getMessage()).join('\n');

      if (output.isEmpty) return null;

      // Parse "Duration: HH:MM:SS.ms"
      final match = RegExp(
        r'Duration:\s*(\d+):(\d+):(\d+\.?\d*)',
      ).firstMatch(output);

      if (match == null) {
        print('Tidak bisa parse durasi dari: $output');
        return null;
      }

      final h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final s = double.parse(match.group(3)!);
      final total = h * 3600 + m * 60 + s;

      print('Duration parsed: ${h}h ${m}m ${s}s = ${total}s');
      return total;
    } catch (e) {
      print('Error _getAudioDuration: $e');
      return null;
    }
  }

  // ── Helper: hapus file tanpa throw jika tidak ada ─────────
  void _safeDelete(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      print('Warning: gagal hapus file $path: $e');
    }
  }

  // ── Cleanup temp files lama (opsional, panggil saat init) ──
  Future<void> cleanTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final files = dir.listSync();
      for (final file in files) {
        if (file is File) {
          final name = p.basename(file.path);
          if (name.startsWith('rec_') || name.startsWith('pick_')) {
            _safeDelete(file.path);
          }
        }
      }
    } catch (e) {
      print('Error cleanTempFiles: $e');
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
