// lib/screens/home_screen.dart
// ─────────────────────────────────────────────────────────────
// Layar utama: rekam mic / pilih file → kirim → tampilkan hasil
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/audio_service.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../widgets/emotion_card.dart';

enum AppState { idle, recording, processing, result, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final ApiService _apiService = ApiService();
  final AudioPlayer _player = AudioPlayer();

  AppState _state = AppState.idle;
  String? _wavPath;
  PredictionResult? _result;
  String _errorMsg = '';
  int _countdown = 3;
  bool _isPlaying = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _player.onPlayerStateChanged.listen((s) {
      setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _audioService.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Rekam dari mikrofon ───────────────────────────────
  Future<void> _startRecording() async {
    if (!await _audioService.hasPermission()) {
      _showSnack('Izin mikrofon diperlukan');
      return;
    }

    setState(() {
      _state = AppState.recording;
      _countdown = 3;
      _result = null;
      _wavPath = null;
    });
    _pulseCtrl.repeat(reverse: true);

    final path = await _audioService.recordFromMic(
      onTick: (sec) =>
          setState(() => _countdown = AudioService.maxDurationSec - sec),
    );

    if (!mounted) return;

    if (path == null) {
      setState(() {
        _state = AppState.error;
        _errorMsg = 'Gagal merekam audio.';
      });
      return;
    }

    setState(() {
      _wavPath = path;
      _state = AppState.processing;
    });
    await _sendToApi(path);
  }

  // ── Pilih file audio ──────────────────────────────────
  Future<void> _pickFile() async {
    setState(() {
      _state = AppState.processing;
      _result = null;
    });

    final path = await _audioService.pickAndProcessFile();

    if (!mounted) return;

    if (path == null) {
      setState(() => _state = AppState.idle);
      return;
    }

    setState(() => _wavPath = path);
    await _sendToApi(path);
  }

  // ── Kirim ke API ──────────────────────────────────────
  Future<void> _sendToApi(String wavPath) async {
    setState(() => _state = AppState.processing);
    try {
      final result = await _apiService.predict(wavPath);
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = AppState.result;
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Koneksi gagal';
      setState(() {
        _state = AppState.error;
        _errorMsg = msg;
      });
    } catch (e) {
      setState(() {
        _state = AppState.error;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Preview audio ─────────────────────────────────────
  Future<void> _togglePlayback() async {
    if (_wavPath == null) return;
    if (_isPlaying) {
      await _player.stop();
    } else {
      await _player.play(DeviceFileSource(_wavPath!));
    }
  }

  void _reset() => setState(() {
    _state = AppState.idle;
    _result = null;
    _wavPath = null;
  });

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [_buildHeader(), const SizedBox(height: 8), _buildBody()],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Color(0xFF6C63FF),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VoiceEmo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                'Emotion Recognition',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const Spacer(),
          // Status server
          FutureBuilder<bool>(
            future: _apiService.isServerReady(),
            builder: (ctx, snap) {
              final online = snap.data ?? false;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (online ? const Color(0xFF4CAF50) : Colors.grey)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: online
                          ? const Color(0xFF4CAF50)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        color: online ? const Color(0xFF4CAF50) : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Body: tergantung state ────────────────────────────
  Widget _buildBody() {
    switch (_state) {
      case AppState.idle:
        return _buildIdleView();
      case AppState.recording:
        return _buildRecordingView();
      case AppState.processing:
        return _buildProcessingView();
      case AppState.result:
        return _buildResultView();
      case AppState.error:
        return _buildErrorView();
    }
  }

  // ── Idle: 2 tombol pilihan input ──────────────────────
  Widget _buildIdleView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Ilustrasi
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 24),
          Text(
            'Detect Your Emotion',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rekam suara atau pilih file audio\nmaks 3 detik',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 40),

          // Tombol Rekam
          _ActionButton(
            icon: Icons.mic_rounded,
            label: 'Rekam Suara',
            subtitle: 'Gunakan mikrofon · 3 detik',
            color: const Color(0xFF6C63FF),
            onTap: _startRecording,
          ),
          const SizedBox(height: 14),

          // Tombol Pilih File
          _ActionButton(
            icon: Icons.audio_file_rounded,
            label: 'Pilih File Audio',
            subtitle: 'mp3, wav, m4a, dll · dipotong 3 detik',
            color: const Color(0xFF26A69A),
            onTap: _pickFile,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Recording: countdown + animasi ───────────────────
  Widget _buildRecordingView() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE53935).withOpacity(0.4),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Color(0xFFE53935),
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Sedang Merekam...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$_countdown',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE53935),
            ),
          ),
          Text(
            'detik tersisa',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () async {
              await _audioService.stopRecording();
              setState(() => _state = AppState.idle);
            },
            icon: const Icon(Icons.stop_rounded, color: Color(0xFFE53935)),
            label: const Text(
              'Hentikan',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Processing: loading ───────────────────────────────
  Widget _buildProcessingView() {
    return const Padding(
      padding: EdgeInsets.all(60),
      child: Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'Menganalisis suara...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Mengirim ke server & prediksi',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Result: EmotionCard + tombol ulang ───────────────
  Widget _buildResultView() {
    return Column(
      children: [
        if (_wavPath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.audio_file_rounded,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _wavPath!.split('/').last,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _togglePlayback,
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: const Color(0xFF6C63FF),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_result != null) EmotionCard(result: _result!),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Error ─────────────────────────────────────────────
  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Action Button ────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
