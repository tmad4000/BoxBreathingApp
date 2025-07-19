import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'box_painter.dart';
import 'audio_controller.dart';

void main() {
  runApp(const BoxBreathingApp());
}

class BoxBreathingApp extends StatelessWidget {
  const BoxBreathingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Box Breathing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'SF Pro Display',
      ),
      home: const BreathingScreen(),
    );
  }
}

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({Key? key}) : super(key: key);

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _boxAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _boxProgressAnimation;
  Timer? _timer;
  
  int _currentStep = 0;
  int _countdown = 4;
  bool _isRunning = false;
  
  final AudioController _audioController = AudioController();
  bool _soundEnabled = true;
  
  final List<String> _instructions = [
    'Inhale',
    'Hold',
    'Exhale',
    'Hold',
  ];
  
  final List<Color> _stepColors = [
    const Color(0xFF4FC3F7), // Inhale - Light Blue
    const Color(0xFF81C784), // Hold - Light Green
    const Color(0xFFBA68C8), // Exhale - Light Purple
    const Color(0xFFFFB74D), // Hold - Light Orange
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    
    _boxAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _boxProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _boxAnimationController,
      curve: Curves.linear,
    ));
    
    // Initialize audio controller
    _audioController.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _boxAnimationController.dispose();
    _audioController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startBreathing() {
    setState(() {
      _isRunning = true;
      _currentStep = 0;
      _countdown = 4;
    });
    _audioController.playStartSound();
    _audioController.startAmbient();
    _runCycle();
  }

  void _pauseBreathing() {
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
    _animationController.stop();
    _audioController.playPauseSound();
  }

  void _resetBreathing() {
    setState(() {
      _isRunning = false;
      _currentStep = 0;
      _countdown = 4;
    });
    _timer?.cancel();
    _animationController.reset();
    _boxAnimationController.reset();
    _audioController.playResetSound();
  }

  void _runCycle() {
    if (!_isRunning) return;

    // Start animation for inhale and exhale
    if (_currentStep == 0) {
      _animationController.forward();
    } else if (_currentStep == 2) {
      _animationController.reverse();
    }
    
    // Start box animation for current step
    _boxAnimationController.reset();
    _boxAnimationController.forward();
    
    // Play sound for current breathing step
    _audioController.playBreathingSound(_currentStep);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdown--;
      });

      if (_countdown == 0) {
        timer.cancel();
        // Play transition sound
        _audioController.playTransitionSound();
        setState(() {
          _currentStep = (_currentStep + 1) % 4;
          _countdown = 4;
        });
        _runCycle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Box Breathing',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _soundEnabled = !_soundEnabled;
                _audioController.setSoundEnabled(_soundEnabled);
              });
            },
            icon: Icon(
              _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0C29),
              Color(0xFF24243e),
              Color(0xFF302b63),
              Color(0xFF24243e),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  
                  // Title
                  const Text(
                    'Find Your Breath',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Breathe • Hold • Release • Rest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Box Breathing visualization
                  AnimatedBuilder(
                    animation: Listenable.merge([_scaleAnimation, _pulseAnimation, _glowAnimation, _boxProgressAnimation]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 320,
                          height: 320,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background glow
                              Container(
                                width: 320,
                                height: 320,
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _stepColors[_currentStep].withOpacity(_glowAnimation.value * 0.5),
                                      blurRadius: 60,
                                      spreadRadius: 15,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Animated Box
                              CustomPaint(
                                size: const Size(280, 280),
                                painter: BoxBreathingPainter(
                                  progress: _boxProgressAnimation.value,
                                  currentStep: _currentStep,
                                  stepColor: _stepColors[_currentStep],
                                  glowIntensity: _glowAnimation.value,
                                ),
                              ),
                              
                              // Center content
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _instructions[_currentStep],
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _countdown.toString(),
                                      style: const TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w100,
                                        color: Colors.white,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModernButton(
                        onPressed: _isRunning ? null : _startBreathing,
                        icon: Icons.play_arrow_rounded,
                        label: 'Start',
                        color: const Color(0xFF4FC3F7),
                        isEnabled: !_isRunning,
                      ),
                      _buildModernButton(
                        onPressed: _isRunning ? _pauseBreathing : null,
                        icon: Icons.pause_rounded,
                        label: 'Pause',
                        color: const Color(0xFFFFB74D),
                        isEnabled: _isRunning,
                      ),
                      _buildModernButton(
                        onPressed: _resetBreathing,
                        icon: Icons.refresh_rounded,
                        label: 'Reset',
                        color: const Color(0xFFBA68C8),
                        isEnabled: true,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'The Art of Mindful Breathing',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Box breathing is a powerful technique used by Navy SEALs and meditation practitioners to reduce stress and enhance focus. Follow the animated box as it traces the four sides of breathing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.6,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildModernButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isEnabled,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isEnabled
              ? RadialGradient(
                  colors: [
                    color.withOpacity(0.8),
                    color.withOpacity(0.3),
                  ],
                )
              : RadialGradient(
                  colors: [
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.1),
                  ],
                ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : [],
          border: Border.all(
            color: isEnabled ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isEnabled ? Colors.white : Colors.grey.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w300,
                color: isEnabled ? Colors.white : Colors.grey.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}