// lib/services/pulse_detector_service.dart
import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Photoplethysmography (PPG) pulse detector.
/// The user places their finger over the rear camera + flash.
/// Brightness fluctuations caused by blood-flow pulsation are
/// analysed to compute heart rate (BPM).
class PulseDetectorService extends ChangeNotifier {
  CameraController? _controller;
  StreamSubscription? _frameSubscription;

  // ── State ──────────────────────────────────────────────────────────────────
  bool   _isRunning        = false;
  bool   _fingerDetected   = false;
  int    _bpm              = 0;
  double _currentBrightness= 0;
  String _statusMessage    = 'Place your finger over the camera lens';
  List<double> _bpmHistory = [];

  // Internal signal buffers
  final List<double> _brightnessBuffer = [];
  final List<int>    _peakTimestamps   = [];
  DateTime?          _lastFrameTime;
  static const int   _bufferSize = 150;   // ~5 seconds at 30 fps
  static const int   _minBrightForFinger = 40; // threshold to detect finger

  // ── Public getters ─────────────────────────────────────────────────────────
  bool   get isRunning       => _isRunning;
  bool   get fingerDetected  => _fingerDetected;
  int    get bpm             => _bpm;
  double get currentBrightness => _currentBrightness;
  String get statusMessage   => _statusMessage;
  List<double> get bpmHistory=> List.unmodifiable(_bpmHistory);

  // ── Initialise camera ─────────────────────────────────────────────────────
  Future<void> initialise() async {
    final cameras = await availableCameras();
    final rear    = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      rear,
      ResolutionPreset.low,       // low res = faster frame processing
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    notifyListeners();
  }

  // ── Start measurement ─────────────────────────────────────────────────────
  Future<void> startMeasurement() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Enable flash (torch) to illuminate blood flow through fingertip
    await _controller!.setFlashMode(FlashMode.torch);

    _isRunning       = true;
    _fingerDetected  = false;
    _bpm             = 0;
    _brightnessBuffer.clear();
    _peakTimestamps.clear();
    _bpmHistory.clear();
    _statusMessage   = 'Place your finger over the camera lens';
    notifyListeners();

    await _controller!.startImageStream(_processFrame);
  }

  // ── Stop measurement ──────────────────────────────────────────────────────
  Future<void> stopMeasurement() async {
    if (_controller?.value.isStreamingImages == true) {
      await _controller!.stopImageStream();
    }
    await _controller?.setFlashMode(FlashMode.off);
    _isRunning = false;
    notifyListeners();
  }

  // ── Frame processing ───────────────────────────────────────────────────────
  void _processFrame(CameraImage image) {
    final now = DateTime.now();
    _lastFrameTime = now;

    // Extract average red-channel brightness from YUV420 frame
    final brightness = _extractBrightness(image);
    _currentBrightness = brightness;

    // Detect finger: finger coverage turns image very dark-red (low Y)
    _fingerDetected = brightness < _minBrightForFinger && brightness > 5;

    if (!_fingerDetected) {
      _statusMessage = 'Cover camera lens completely with your fingertip';
      _brightnessBuffer.clear();
      notifyListeners();
      return;
    }

    _statusMessage = 'Measuring… keep finger still';
    _brightnessBuffer.add(brightness);
    if (_brightnessBuffer.length > _bufferSize) {
      _brightnessBuffer.removeAt(0);
    }

    // Need at least 2 seconds of data before computing BPM
    if (_brightnessBuffer.length >= 60) {
      _computeBPM();
    }

    notifyListeners();
  }

  // ── Extract brightness ─────────────────────────────────────────────────────
  double _extractBrightness(CameraImage image) {
    // YUV420: Y plane is brightness; average the Y plane values
    final yPlane = image.planes[0];
    final bytes  = yPlane.bytes;
    double sum   = 0;
    final step   = max(1, bytes.length ~/ 500); // sample ~500 pixels
    int count    = 0;
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
    }
    return count > 0 ? sum / count : 0;
  }

  // ── BPM computation via peak detection ────────────────────────────────────
  void _computeBPM() {
    final signal = _brightnessBuffer;
    // Smooth signal with simple moving average
    final smoothed = _movingAverage(signal, 5);
    // Find peaks (local maxima above mean)
    final mean    = smoothed.reduce((a, b) => a + b) / smoothed.length;
    final peaks   = <int>[];
    for (int i = 1; i < smoothed.length - 1; i++) {
      if (smoothed[i] > smoothed[i-1] &&
          smoothed[i] > smoothed[i+1] &&
          smoothed[i] > mean * 0.98) {
        if (peaks.isEmpty || (i - peaks.last) > 5) {
          peaks.add(i);
        }
      }
    }

    if (peaks.length >= 2) {
      // Average interval between peaks → BPM
      // Assuming ~30 fps
      const fps = 30.0;
      final intervals = <double>[];
      for (int i = 1; i < peaks.length; i++) {
        intervals.add((peaks[i] - peaks[i-1]) / fps); // seconds
      }
      final avgInterval = intervals.reduce((a,b)=>a+b) / intervals.length;
      final rawBPM      = (60.0 / avgInterval).round();

      // Sanity clamp: physiological BPM range
      if (rawBPM >= 45 && rawBPM <= 180) {
        _bpm = rawBPM;
        _bpmHistory.add(rawBPM.toDouble());
        if (_bpmHistory.length > 30) _bpmHistory.removeAt(0);
        _statusMessage = 'Pulse detected: $_bpm BPM';
      }
    }
  }

  List<double> _movingAverage(List<double> data, int window) {
    final result = <double>[];
    for (int i = 0; i < data.length; i++) {
      final start = max(0, i - window ~/ 2);
      final end   = min(data.length - 1, i + window ~/ 2);
      final slice = data.sublist(start, end + 1);
      result.add(slice.reduce((a,b)=>a+b) / slice.length);
    }
    return result;
  }

  CameraController? get cameraController => _controller;

  @override
  void dispose() {
    stopMeasurement();
    _controller?.dispose();
    super.dispose();
  }
}
