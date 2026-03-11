// lib/screens/input_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/tflite_service.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});
  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageCtrl       = TextEditingController(text: '35');
  final _pulseCtrl     = TextEditingController(text: '72');
  final _oxygenCtrl    = TextEditingController(text: '98');
  double _activityLevel = 3;

  bool _isLoading = false;
  HealthPrediction? _result;

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _result = null; });

    try {
      final svc = context.read<TFLiteService>();
      final pred = await svc.predict(
        age: double.parse(_ageCtrl.text),
        pulseRate: double.parse(_pulseCtrl.text),
        oxygenLevel: double.parse(_oxygenCtrl.text),
        activityLevel: _activityLevel,
      );
      setState(() { _result = pred; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prediction error: $e'), backgroundColor: AppTheme.accentRed));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Health Risk Prediction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            _buildCard('Patient Parameters', Icons.person_outline, [
              _buildTextField(_ageCtrl, 'Age', 'years', min: 18, max: 100),
              const SizedBox(height: 16),
              _buildTextField(_pulseCtrl, 'Pulse Rate', 'BPM', min: 40, max: 200),
              const SizedBox(height: 16),
              _buildTextField(_oxygenCtrl, 'Oxygen Level (SpO₂)', '%', min: 80, max: 100, isDecimal: true),
              const SizedBox(height: 16),
              _buildActivitySlider(),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _predict,
                icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.psychology_alt),
                label: Text(_isLoading ? 'Running Inference…' : 'Predict Health Risk'),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultCard(prediction: _result!),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 20),
        ...children,
      ]),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String unit,
      {required double min, required double max, bool isDecimal = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        suffixStyle: const TextStyle(color: AppTheme.accent),
      ),
      validator: (v) {
        final d = double.tryParse(v ?? '');
        if (d == null) return 'Enter a valid number';
        if (d < min || d > max) return 'Must be between $min and $max';
        return null;
      },
    );
  }

  Widget _buildActivitySlider() {
    final labels = ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Activity Level', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(labels[_activityLevel.round() - 1],
            style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
      Slider(
        value: _activityLevel, min: 1, max: 5, divisions: 4,
        activeColor: AppTheme.accent,
        onChanged: (v) => setState(() => _activityLevel = v),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labels.map((l) => Text(l.substring(0, 1), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))).toList()),
    ]);
  }

  @override
  void dispose() {
    _ageCtrl.dispose(); _pulseCtrl.dispose(); _oxygenCtrl.dispose();
    super.dispose();
  }
}

// ── Result display ─────────────────────────────────────────────────────────────
class _ResultCard extends StatefulWidget {
  final HealthPrediction prediction;
  const _ResultCard({required this.prediction});
  @override State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _riskColor => switch (widget.prediction.riskLevel) {
    RiskLevel.low      => AppTheme.accentGreen,
    RiskLevel.moderate => const Color(0xFFFFD700),
    RiskLevel.high     => AppTheme.accentRed,
  };

  IconData get _riskIcon => switch (widget.prediction.riskLevel) {
    RiskLevel.low      => Icons.check_circle_outline,
    RiskLevel.moderate => Icons.warning_amber_outlined,
    RiskLevel.high     => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.prediction;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _riskColor.withOpacity(0.4), width: 1.5),
            boxShadow: [BoxShadow(color: _riskColor.withOpacity(0.12), blurRadius: 24)],
          ),
          child: Column(children: [
            Icon(_riskIcon, color: _riskColor, size: 48),
            const SizedBox(height: 12),
            Text(p.riskLabel, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _riskColor)),
            const SizedBox(height: 8),
            Text('Risk Score: ${(p.score * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: p.score,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation(_riskColor),
              borderRadius: BorderRadius.circular(4), minHeight: 8,
            ),
            const SizedBox(height: 16),
            Text(p.recommendation,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _Metric('Inference', '${p.inferenceTimeMs} ms', Icons.speed),
                _Divider(),
                _Metric('Engine', 'TFLite', Icons.memory),
                _Divider(),
                _Metric('Precision', 'float32', Icons.calculate_outlined),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value; final IconData icon;
  const _Metric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: AppTheme.accent, size: 16),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(height: 32, width: 1, color: AppTheme.cardBorder);
}
