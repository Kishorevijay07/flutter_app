// lib/screens/pulse_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'dart:math';
import '../core/theme.dart';
import '../services/pulse_detector_service.dart';

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});
  @override State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _initialised = false;
  late AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    await context.read<PulseDetectorService>().initialise();
    if (mounted) setState(() => _initialised = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Pulse Detection')),
      body: Consumer<PulseDetectorService>(
        builder: (_, svc, __) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _CameraPreviewCard(svc: svc, initialised: _initialised),
            const SizedBox(height: 16),
            _BPMCard(svc: svc, heartCtrl: _heartCtrl),
            const SizedBox(height: 16),
            _BPMGraph(svc: svc),
            const SizedBox(height: 16),
            _ControlButtons(svc: svc),
            const SizedBox(height: 16),
            _PPGInfoCard(),
          ]),
        ),
      ),
    );
  }
}

class _CameraPreviewCard extends StatelessWidget {
  final PulseDetectorService svc; final bool initialised;
  const _CameraPreviewCard({required this.svc, required this.initialised});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200, decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: svc.fingerDetected ? AppTheme.accentRed : AppTheme.cardBorder, width: svc.fingerDetected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: !initialised
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : svc.cameraController == null
          ? const Center(child: Text('Camera unavailable', style: TextStyle(color: AppTheme.textSecondary)))
          : Stack(children: [
              CameraPreview(svc.cameraController!),
              Container(color: Colors.black38),
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fingerprint, color: svc.fingerDetected ? AppTheme.accentRed : Colors.white54, size: 48),
                const SizedBox(height: 8),
                Text(svc.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: svc.fingerDetected ? AppTheme.accentRed : Colors.white70, fontWeight: FontWeight.w500)),
              ])),
            ]),
    );
  }
}

class _BPMCard extends StatelessWidget {
  final PulseDetectorService svc; final AnimationController heartCtrl;
  const _BPMCard({required this.svc, required this.heartCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1A0A0A), AppTheme.surface]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: heartCtrl,
          builder: (_, __) => Transform.scale(
            scale: svc.isRunning && svc.fingerDetected ? 0.9 + heartCtrl.value * 0.2 : 1.0,
            child: Icon(Icons.favorite, color: AppTheme.accentRed,
              size: svc.isRunning && svc.fingerDetected ? 52 : 48),
          ),
        ),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: svc.bpm > 0 ? '${svc.bpm}' : '--',
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, color: AppTheme.accentRed, fontFamily: 'Poppins')),
            const TextSpan(text: ' BPM', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, fontFamily: 'Poppins')),
          ])),
          Text(_bpmStatus(svc.bpm), style: TextStyle(color: _bpmColor(svc.bpm), fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  String _bpmStatus(int bpm) {
    if (bpm == 0) return 'Not measuring';
    if (bpm < 60) return 'Below normal';
    if (bpm <= 100) return 'Normal range';
    if (bpm <= 120) return 'Elevated';
    return 'High — consult physician';
  }

  Color _bpmColor(int bpm) {
    if (bpm == 0) return AppTheme.textSecondary;
    if (bpm < 60 || bpm > 120) return AppTheme.accentRed;
    if (bpm > 100) return const Color(0xFFFFD700);
    return AppTheme.accentGreen;
  }
}

class _BPMGraph extends StatelessWidget {
  final PulseDetectorService svc;
  const _BPMGraph({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: svc.bpmHistory.isEmpty
        ? const Center(child: Text('Start measurement to see BPM trend', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
        : CustomPaint(size: Size.infinite, painter: _BPMLinePainter(svc.bpmHistory)),
    );
  }
}

class _BPMLinePainter extends CustomPainter {
  final List<double> data;
  _BPMLinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce(min) - 5;
    final maxV = data.reduce(max) + 5;
    final range = (maxV - minV).clamp(1.0, double.infinity);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - (data[i] - minV) / range * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(path, Paint()
      ..color = AppTheme.accentRed..style = PaintingStyle.stroke
      ..strokeWidth = 2..strokeCap = StrokeCap.round);

    // Fill under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, Paint()..color = AppTheme.accentRed.withOpacity(0.1));
  }

  @override bool shouldRepaint(_BPMLinePainter old) => old.data != data;
}

class _ControlButtons extends StatelessWidget {
  final PulseDetectorService svc;
  const _ControlButtons({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: ElevatedButton.icon(
        onPressed: svc.isRunning ? null : () => svc.startMeasurement(),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
        icon: const Icon(Icons.play_arrow), label: const Text('Start'),
      )),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton.icon(
        onPressed: svc.isRunning ? () => svc.stopMeasurement() : null,
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
        icon: const Icon(Icons.stop), label: const Text('Stop'),
      )),
    ]);
  }
}

class _PPGInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: AppTheme.accent, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How PPG Works', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Text('Place your finger firmly on the rear camera and flashlight. '
            'Blood flow variations cause brightness changes, which are analysed '
            'using Photoplethysmography to detect pulse peaks and calculate BPM.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
        ])),
      ]),
    );
  }
}
