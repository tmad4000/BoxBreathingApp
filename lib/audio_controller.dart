import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioController {
  static final AudioController _instance = AudioController._internal();
  factory AudioController() => _instance;
  AudioController._internal();

  final AudioPlayer _effectsPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _ambientEnabled = true;
  double _volume = 0.7;

  bool get soundEnabled => _soundEnabled;
  bool get ambientEnabled => _ambientEnabled;
  double get volume => _volume;

  Future<void> initialize() async {
    try {
      await _effectsPlayer.setReleaseMode(ReleaseMode.stop);
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.setVolume(_volume * 0.3);
      await _effectsPlayer.setVolume(_volume);
    } catch (e) {
      print('Audio initialization failed: $e');
    }
  }

  Future<void> playBreathingSound(int step) async {
    if (!_soundEnabled) return;
    
    try {
      await _effectsPlayer.stop();
      
      // Play different system sounds for each step
      switch (step) {
        case 0: // Inhale - ascending sound
          await SystemSound.play(SystemSoundType.click);
          await Future.delayed(const Duration(milliseconds: 100));
          await SystemSound.play(SystemSoundType.click);
          break;
        case 1: // Hold - single sustained sound
          await SystemSound.play(SystemSoundType.click);
          break;
        case 2: // Exhale - descending sound
          await SystemSound.play(SystemSoundType.click);
          await Future.delayed(const Duration(milliseconds: 50));
          await SystemSound.play(SystemSoundType.click);
          break;
        case 3: // Hold - single sustained sound
          await SystemSound.play(SystemSoundType.click);
          break;
      }
      
      // Add haptic feedback for better user experience
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Error playing breathing sound: $e');
    }
  }

  Future<void> playTransitionSound() async {
    if (!_soundEnabled) return;
    
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.selectionClick();
    } catch (e) {
      print('Error playing transition sound: $e');
    }
  }

  Future<void> playStartSound() async {
    if (!_soundEnabled) return;
    
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (e) {
      print('Error playing start sound: $e');
    }
  }

  Future<void> playPauseSound() async {
    if (!_soundEnabled) return;
    
    try {
      await HapticFeedback.lightImpact();
      await stopAmbient();
    } catch (e) {
      print('Error playing pause sound: $e');
    }
  }

  Future<void> playResetSound() async {
    if (!_soundEnabled) return;
    
    try {
      await HapticFeedback.heavyImpact();
      await stopAll();
    } catch (e) {
      print('Error playing reset sound: $e');
    }
  }

  Future<void> startAmbient() async {
    if (!_ambientEnabled) return;
    
    try {
      // In a real implementation, you would play ambient sounds here
      // For now, we'll just indicate ambient mode is active
      print('Ambient sounds started');
    } catch (e) {
      print('Error starting ambient sounds: $e');
    }
  }

  Future<void> stopAmbient() async {
    try {
      await _ambientPlayer.stop();
    } catch (e) {
      print('Error stopping ambient sounds: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await _effectsPlayer.stop();
      await _ambientPlayer.stop();
    } catch (e) {
      print('Error stopping all sounds: $e');
    }
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    if (!enabled) {
      stopAll();
    }
  }

  void setAmbientEnabled(bool enabled) {
    _ambientEnabled = enabled;
    if (!enabled) {
      stopAmbient();
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _effectsPlayer.setVolume(_volume);
    _ambientPlayer.setVolume(_volume * 0.3);
  }

  void dispose() {
    _effectsPlayer.dispose();
    _ambientPlayer.dispose();
  }
}

// Sound effect helper class for generating breathing sounds
class BreathingSounds {
  static const Map<int, String> stepNames = {
    0: 'Inhale',
    1: 'Hold',
    2: 'Exhale', 
    3: 'Hold',
  };

  static const Map<int, double> stepFrequencies = {
    0: 440.0, // A4 - Inhale (rising)
    1: 523.0, // C5 - Hold (stable high)
    2: 349.0, // F4 - Exhale (falling)
    3: 392.0, // G4 - Hold (stable low)
  };

  static String getStepDescription(int step) {
    return stepNames[step] ?? 'Unknown';
  }

  static double getStepFrequency(int step) {
    return stepFrequencies[step] ?? 440.0;
  }
}