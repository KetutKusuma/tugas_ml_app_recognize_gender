// lib/screens/training_result_screen.dart

import 'package:flutter/material.dart';

class TrainingResultScreen extends StatelessWidget {
  const TrainingResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Training Results',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Dataset'),
            _DatasetCard(),
            SizedBox(height: 20),
            _SectionLabel('Balancing'),
            _BalancingCard(),
            SizedBox(height: 20),
            _SectionLabel('Data Distribution'),
            _DistributionCard(),
            SizedBox(height: 20),
            _SectionLabel('Model Results'),
            _ModelCard(
              name: 'SVM',
              badge: 'Terbaik',
              badgeColor: Color(0xFF6C63FF),
              params: 'kernel=rbf · C=5.0 · gamma=scale',
              trainF1: 1.0000,
              valF1: 1.0000,
              gap: 0.0000,
              confusionAsset: 'assets/result/cm_svm.png',
            ),
            SizedBox(height: 12),
            _ModelCard(
              name: 'XGBoost',
              badge: 'Runner-up',
              badgeColor: Color(0xFF26A69A),
              params: 'n_est=300 · max_depth=5 · lr=0.1',
              trainF1: 1.0000,
              valF1: 0.9957,
              gap: 0.0043,
              confusionAsset: 'assets/result/cm_xgboost.png',
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[400],
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ── Dataset Card ──────────────────────────────────────
class _DatasetCard extends StatelessWidget {
  const _DatasetCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        children: [
          _DataRow(
            label: 'Male',
            count: '10,380 file',
            color: const Color(0xFF6C63FF),
            fraction: 1.0,
          ),
          const SizedBox(height: 10),
          _DataRow(
            label: 'Female',
            count: '5,768 file',
            color: const Color(0xFF26A69A),
            fraction: 5768 / 10380,
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String count;
  final Color color;
  final double fraction;

  const _DataRow({
    required this.label,
    required this.count,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: color),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
              ],
            ),
            Text(count,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Balancing Card ────────────────────────────────────
class _BalancingCard extends StatelessWidget {
  const _BalancingCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        children: [
          _BalanceRow(label: 'Sebelum · Male', value: '10,380', color: Colors.orange.shade300),
          const SizedBox(height: 8),
          _BalanceRow(label: 'Sebelum · Female', value: '5,768', color: Colors.orange.shade300),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Undersample → 5,768/kelas',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          _BalanceRow(label: 'Sesudah · Male', value: '5,768', color: const Color(0xFF6C63FF)),
          const SizedBox(height: 8),
          _BalanceRow(label: 'Sesudah · Female', value: '5,768', color: const Color(0xFF26A69A)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Total: 11,536 sampel · Balanced ✓',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6C63FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
      ],
    );
  }
}

// ── Distribution Card ─────────────────────────────────
class _DistributionCard extends StatelessWidget {
  const _DistributionCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi Pitch per Gender',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/result/pitch_distribution.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(color: const Color(0xFF6C63FF), label: 'Male ≈ 100–155 Hz'),
              const SizedBox(width: 16),
              _LegendDot(color: const Color(0xFF26A69A), label: 'Female ≈ 165–220 Hz'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ── Model Card ────────────────────────────────────────
class _ModelCard extends StatelessWidget {
  final String name;
  final String badge;
  final Color badgeColor;
  final String params;
  final double trainF1;
  final double valF1;
  final double gap;
  final String confusionAsset;

  const _ModelCard({
    required this.name,
    required this.badge,
    required this.badgeColor,
    required this.params,
    required this.trainF1,
    required this.valF1,
    required this.gap,
    required this.confusionAsset,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(params, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 14),

          // Metrics
          Row(
            children: [
              _MetricBox(label: 'Train F1', value: trainF1.toStringAsFixed(4), color: badgeColor),
              const SizedBox(width: 8),
              _MetricBox(label: 'Val F1', value: valF1.toStringAsFixed(4), color: badgeColor),
              const SizedBox(width: 8),
              _MetricBox(label: 'Gap', value: gap.toStringAsFixed(4), color: Colors.grey),
            ],
          ),
          const SizedBox(height: 14),

          // Confusion matrix image
          Text('Confusion Matrix',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              confusionAsset,
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

// ── Base Card ─────────────────────────────────────────
class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }
}