// lib/services/tflite_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;
  List<double> _mean = [];
  List<double> _scale = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      final scalerJson =
          await rootBundle.loadString('assets/models/scaler_params.json');
      final scalerData = json.decode(scalerJson) as Map<String, dynamic>;
      _mean = List<double>.from(
          (scalerData['mean'] as List).map((e) => (e as num).toDouble()));
      _scale = List<double>.from(
          (scalerData['scale'] as List).map((e) => (e as num).toDouble()));
      final interpreterOptions = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
        'assets/models/health_model.tflite',
        options: interpreterOptions,
      );
      _isLoaded = true;
      print('[TFLiteService] Model loaded OK');
    } catch (e) {
      _isLoaded = false;
      print('[TFLiteService] Error: $e');
      rethrow;
    }
  }

  List<double> _standardise(List<double> raw) {
    return List.generate(raw.length, (i) => (raw[i] - _mean[i]) / _scale[i]);
  }

  Future<HealthPrediction> predict({
    required double age,
    required double pulseRate,
    required double oxygenLevel,
    required double activityLevel,
  }) async {
    if (!_isLoaded || _interpreter == null) {
      throw Exception('Model not loaded');
    }

    final raw = [age, pulseRate, oxygenLevel, activityLevel];
    final normalised = _standardise(raw);

    // 0.9.0 API uses typed lists directly
    var input = [normalised];
    var output = List.generate(1, (_) => List.filled(1, 0.0));

    final stopwatch = Stopwatch()..start();
    _interpreter!.run(input, output);
    stopwatch.stop();

    final score = (output[0][0] as double);
    return HealthPrediction(
      score: score,
      riskLevel: _classifyRisk(score),
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
      inputs: {
        'age': age,
        'pulse_rate': pulseRate,
        'oxygen_level': oxygenLevel,
        'activity_level': activityLevel
      },
    );
  }

  RiskLevel _classifyRisk(double score) {
    if (score < 0.35) return RiskLevel.low;
    if (score < 0.65) return RiskLevel.moderate;
    return RiskLevel.high;
  }

  void dispose() => _interpreter?.close();
}

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
        RiskLevel.low => 'Low Risk',
        RiskLevel.moderate => 'Moderate Risk',
        RiskLevel.high => 'High Risk',
      };

  String get recommendation => switch (riskLevel) {
        RiskLevel.low =>
          'Your vitals look great! Maintain your healthy lifestyle.',
        RiskLevel.moderate =>
          'Some indicators are elevated. Consider consulting a physician.',
        RiskLevel.high =>
          'Multiple risk factors detected. Please seek medical advice promptly.',
      };
}
