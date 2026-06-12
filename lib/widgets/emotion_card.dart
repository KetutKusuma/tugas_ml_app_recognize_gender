// lib/widgets/emotion_card.dart
// ─────────────────────────────────────────────────────────────
// Card hasil prediksi dengan emoji + bar probabilitas
// ─────────────────────────────────────────────────────────────
// ini ga kepake anjerr
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmotionCard extends StatelessWidget {
  final PredictionResult result;

  const EmotionCard({super.key, required this.result});

  // Emoji & warna per label emosi
  static const Map<String, String> _emoji = {
    'angry': '😠',
    'disgust': '🤢',
    'fear': '😨',
    'happy': '😊',
    'neutral': '😐',
    'sad': '😢',
    'surprise': '😲',
    'calm': '😌',
  };

  static const Map<String, Color> _color = {
    'angry': Color(0xFFE53935),
    'disgust': Color(0xFF8BC34A),
    'fear': Color(0xFF7E57C2),
    'happy': Color(0xFFFFB300),
    'neutral': Color(0xFF78909C),
    'sad': Color(0xFF42A5F5),
    'surprise': Color(0xFFFF7043),
    'calm': Color(0xFF26A69A),
  };

  Color _colorFor(String label) =>
      _color[label.toLowerCase()] ?? const Color(0xFF78909C);

  String _emojiFor(String label) => _emoji[label.toLowerCase()] ?? '🎙️';

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(result.prediction);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // ── Header: emoji + label ──────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _emojiFor(result.prediction),
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 8),
                Text(
                  result.gender,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(result.confidence * 100).toStringAsFixed(1)}% confidence',
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // ── Probability bars ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gender Probabilities',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(result.classes.length, (i) {
                  final label = result.genderFromLabel(result.classes[i]);
                  final prob = i < result.probability.length
                      ? result.probability[i]
                      : 0.0;
                  final barColor = _colorFor(label);
                  final isTop = label == result.gender;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            _emojiFor(label),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isTop
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isTop ? barColor : Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: prob,
                              minHeight: 6,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(barColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(prob * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isTop
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isTop ? barColor : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
