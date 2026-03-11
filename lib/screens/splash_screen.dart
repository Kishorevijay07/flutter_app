// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/tflite_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  String _status = 'Initialising…';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _status = 'Loading AI model…');
    try {
      await context.read<TFLiteService>().loadModel();
      setState(() => _status = 'Ready!');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_,a,b) => const HomeScreen(),
          transitionsBuilder: (_,a,b,child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      setState(() => _status = 'Model load failed: $e');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Animated logo
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.healthGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 32, spreadRadius: 4)],
                ),
                child: const Icon(Icons.monitor_heart, color: Colors.black, size: 52),
              ),
              const SizedBox(height: 28),
              ShaderMask(
                shaderCallback: (b) => AppTheme.accentGradient.createShader(b),
                child: const Text('HealthAI Monitor',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text('AI-Powered Health Risk Prediction',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 48),
              SizedBox(width: 200, child: LinearProgressIndicator(
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                borderRadius: BorderRadius.circular(4),
              )),
              const SizedBox(height: 16),
              Text(_status, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}
