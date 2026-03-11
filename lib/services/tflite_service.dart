// lib/services/tflite_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Wraps TFLite Interpreter for health-risk inference.
/// Input features : [age, pulse_rate, oxygen_level, activity_level]
/// Output          : health_risk_score ∈ [0.0, 1.0]
class TFLiteService {
  Interpreter? _interpreter;
  List<double> _mean  = [];
  List<double> _scale = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // ── Initialise ─────────────────────────────────────────────────────────────
  Future<void> loadModel() async {
    try {
      // Load scaler parameters (mean & std for each feature)
      final scalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
      final scalerData = json.decode(scalerJson) as Map<String, dynamic>;
      _mean  = List<double>.from(scalerData['mean']);
      _scale = List<double>.from(scalerData['scale']);

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/models/health_model.tflite');
      _isLoaded = true;
      print('[TFLiteService] Model loaded successfully.');
      print('[TFLiteService] Input  tensor: ${_interpreter!.getInputTensor(0)}');
      print('[TFLiteService] Output tensor: ${_interpreter!.getOutputTensor(0)}');
    } catch (e) {
      _isLoaded = false;
      print('[TFLiteService] Error loading model: $e');
      rethrow;
    }
  }

  // ── Standardise inputs ─────────────────────────────────────────────────────
  List<double> _standardise(List<double> raw) {
    return List.generate(raw.length, (i) => (raw[i] - _mean[i]) / _scale[i]);
  }

  // ── Predict ────────────────────────────────────────────────────────────────
  /// Returns health risk score between 0.0 (low) and 1.0 (high).
  Future<HealthPrediction> predict({
    required double age,
    required double pulseRate,
    required double oxygenLevel,
    required double activityLevel,
  }) async {
    if (!_isLoaded || _interpreter == null) {
      throw Exception('TFLite model not loaded. Call loadModel() first.');
    }

    final raw        = [age, pulseRate, oxygenLevel, activityLevel];
    final normalised = _standardise(raw);

    // Input  shape: [1, 4]   dtype: float32
    // Output shape: [1, 1]   dtype: float32
    var input  = [normalised.map((v) => v.toDouble()).toList()];
    var output = List.filled(1, List.filled(1, 0.0));

    final stopwatch = Stopwatch()..start();
    _interpreter!.run(input, output);
    stopwatch.stop();

    final score = output[0][0];
    return HealthPrediction(
      score          : score,
      riskLevel      : _classifyRisk(score),
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
      inputs         : {'age': age, 'pulse_rate': pulseRate,
                        'oxygen_level': oxygenLevel, 'activity_level': activityLevel},
    );
  }

  RiskLevel _classifyRisk(double score) {
    if (score < 0.35) return RiskLevel.low;
    if (score < 0.65) return RiskLevel.moderate;
    return RiskLevel.high;
  }

  void dispose() => _interpreter?.close();
}

// ── Data models ───────────────────────────────────────────────────────────────
enum RiskLevel { low, moderate, high }

class HealthPrediction {
  final double score;
  final RiskLevel riskLevel;
  final int inferenceTimeMs;
  final Map<String, double> inputs;
  final DateTime timestamp;

  HealthPrediction({
    required this.score,
    required this.riskLevel,
    required this.inferenceTimeMs,
    required this.inputs,
  }) : timestamp = DateTime.now();

  String get riskLabel => switch (riskLevel) {
    RiskLevel.low      => 'Low Risk',
    RiskLevel.moderate => 'Moderate Risk',
    RiskLevel.high     => 'High Risk',
  };

  String get recommendation => switch (riskLevel) {
    RiskLevel.low      => 'Your vitals look great! Maintain your healthy lifestyle.',
    RiskLevel.moderate => 'Some indicators are elevated. Consider consulting a physician.',
    RiskLevel.high     => 'Multiple risk factors detected. Please seek medical advice promptly.',
  };
}
