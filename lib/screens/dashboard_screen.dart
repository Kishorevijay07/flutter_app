// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../core/theme.dart';
import '../services/tflite_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Header(),
            const SizedBox(height: 24),
            _HealthScoreCard(),
            const SizedBox(height: 16),
            _VitalsRow(),
            const SizedBox(height: 16),
            _RiskFactorsCard(),
            const SizedBox(height: 16),
            _DeviceInfoCard(),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Health Monitor', style: Theme.of(context).textTheme.displayLarge),
        Text('AI-powered risk analysis', style: Theme.of(context).textTheme.bodyMedium),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Icon(Icons.notifications_outlined, color: AppTheme.accent),
      ),
    ]);
  }
}

class _HealthScoreCard extends StatefulWidget {
  @override
  State<_HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<_HealthScoreCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  // Placeholder score — in production, comes from last prediction
  static const double _score = 0.28;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _progress = Tween<double>(begin: 0, end: _score).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D1B35), Color(0xFF112240)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.08), blurRadius: 24)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Text('Health Risk Score', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 24),
        Center(
          child: AnimatedBuilder(
            animation: _progress,
            builder: (_, __) => CustomPaint(
              size: const Size(180, 180),
              painter: _RiskGaugePainter(_progress.value),
              child: SizedBox(
                width: 180, height: 180,
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(_score * 100).round()}',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                  Text('/100', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: const Text('LOW RISK', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ])),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your vitals look great! Maintain your healthy lifestyle.', style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double value;
  _RiskGaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;

    // Background arc
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()..color = AppTheme.surfaceLight..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round);

    // Gradient value arc
    final gradient = SweepGradient(
      colors: const [AppTheme.accentGreen, Color(0xFFFFD700), AppTheme.accentRed],
      startAngle: startAngle, endAngle: startAngle + sweepAngle,
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * value, false, paint);
  }

  @override
  bool shouldRepaint(_RiskGaugePainter old) => old.value != value;
}

class _VitalsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _VitalCard(icon: Icons.favorite, label: 'Pulse', value: '72', unit: 'BPM', color: AppTheme.accentRed)),
      const SizedBox(width: 12),
      Expanded(child: _VitalCard(icon: Icons.air, label: 'SpO₂', value: '98', unit: '%', color: AppTheme.accent)),
      const SizedBox(width: 12),
      Expanded(child: _VitalCard(icon: Icons.directions_run, label: 'Activity', value: '3', unit: '/5', color: AppTheme.accentGreen)),
    ]);
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon; final String label, value, unit; final Color color;
  const _VitalCard({required this.icon, required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        RichText(text: TextSpan(children: [
          TextSpan(text: value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
          TextSpan(text: unit, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Poppins')),
        ])),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

class _RiskFactorsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final factors = [
      ('Age', 0.2, AppTheme.accentGreen), ('Pulse Rate', 0.35, AppTheme.accentGreen),
      ('Oxygen Level', 0.15, AppTheme.accentGreen), ('Activity', 0.45, Color(0xFFFFD700)),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Risk Factors', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...factors.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(f.$1, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Text('${(f.$2 * 100).round()}%', style: TextStyle(color: f.$3, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: f.$2, backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation(f.$3), borderRadius: BorderRadius.circular(4), minHeight: 6),
          ]),
        )),
      ]),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.devices, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Text('Device & Model Info', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 16),
        _InfoRow('Model', 'health_model.tflite'),
        _InfoRow('Precision', 'float32'),
        _InfoRow('Inference Engine', 'TensorFlow Lite 2.x'),
        _InfoRow('Input Features', '4 (age, pulse, SpO₂, activity)'),
        _InfoRow('Last Inference', '< 2 ms'),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
