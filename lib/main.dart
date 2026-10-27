import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'box_painter.dart';

void main() => runApp(const BoxBreathingApp());

const _background = Color(0xFF141426);
const _surface = Color(0xFF202037);
const _accent = Color(0xFFBBB5FF);
const _muted = Color(0xFFB9B8CC);
const _native = MethodChannel('com.openinfra.boxBreathingApp/session');
const _source = 'https://github.com/tmad4000/BoxBreathingApp';

class BoxBreathingApp extends StatelessWidget {
  const BoxBreathingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Box Breathing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: _background,
        colorScheme:
            const ColorScheme.dark(primary: _accent, surface: _surface),
        textTheme: const TextTheme(bodyMedium: TextStyle(height: 1.5)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(160, 52),
                textStyle: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600))),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      ),
      home: const BreathingScreen());
}

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _phase;
  int _step = 0, _rounds = 0, _target = 4;
  bool _running = false,
      _started = false,
      _checkpoint = false,
      _haptics = true,
      _sound = true;
  String _version = "1.0.0", _build = "3";
  String? _audioError;
  int _soundGeneration = 0;
  static const _phases = ['Inhale', 'Hold', 'Exhale', 'Hold'];
  static const _spoken = [
    'Inhale',
    'Hold after inhaling',
    'Exhale',
    'Hold after exhaling'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _native.setMethodCallHandler((call) async {
      if (call.method == "audioInterrupted") _pause();
    });
    _phase = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
        animationBehavior: AnimationBehavior.preserve)
      ..addStatusListener(_phaseStatus);
  }

  Future<void> _keepAwake(bool enabled) async {
    try {
      await _native.invokeMethod<void>('keepAwake', enabled);
    } on MissingPluginException {
      /* Non-iOS previews do not change idle policy. */
    }
  }

  void _announce(String message) =>
      SemanticsService.announce(message, TextDirection.ltr);
  Future<void> _loadPreferences() async {
    try {
      final info = await _native.invokeMapMethod<String, dynamic>('info');
      if (mounted && info != null) {
        setState(() {
          _sound = info['soundEnabled'] as bool? ?? true;
          _haptics = info['hapticsEnabled'] as bool? ?? true;
          _version = info['version'] as String? ?? _version;
          _build = info['build'] as String? ?? _build;
        });
      }
    } on MissingPluginException {/* Flutter previews use defaults. */}
  }

  Future<void> _playSound({bool test = false}) async {
    if (!_sound && !test) return;
    final generation = _soundGeneration;
    try {
      final bytes = await rootBundle.load('assets/audio/chime.wav');
      if (!mounted || generation != _soundGeneration || (!_sound && !test)) {
        return;
      }
      await _native.invokeMethod<void>('playSound',
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      if (mounted) setState(() => _audioError = null);
    } on PlatformException {
      if (mounted) {
        setState(() => _audioError =
            'Sound could not play. Check your output device and volume, then test again.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
            () => _audioError = 'Sound playback is available in the iOS app.');
      }
    }
  }

  Future<void> _stopSound() async {
    _soundGeneration++;
    try {
      await _native.invokeMethod<void>('stopSound');
    } on MissingPluginException {/* Preview. */}
  }

  void _cue() {
    if (_haptics) unawaited(HapticFeedback.selectionClick());
    unawaited(_playSound());
  }

  Future<void> _savePreferences() async {
    try {
      await _native.invokeMethod<void>('savePreferences',
          {'soundEnabled': _sound, 'hapticsEnabled': _haptics});
    } on MissingPluginException {/* Preview. */}
  }

  Future<void> _copyDiagnostics() async {
    Map<String, dynamic>? info;
    try {
      info = await _native.invokeMapMethod<String, dynamic>('info');
    } on MissingPluginException {/* Preview. */}
    await Clipboard.setData(ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'appVersion': _version,
      'buildNumber': _build,
      'state': _checkpoint
          ? 'checkpoint'
          : _running
              ? 'running'
              : _started
                  ? 'paused'
                  : 'ready',
      'phase': _spoken[_step],
      'completedRounds': _rounds,
      'checkpointRounds': _target,
      'phaseProgress': _phase.value,
      'soundEnabled': _sound,
      'hapticsEnabled': _haptics,
      'audioError': _audioError,
      'native': info,
    })));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Diagnostics copied. No session history is recorded.')));
    }
  }

  void _phaseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_running) return;
    final completedRound = _step == 3;
    setState(() {
      if (completedRound) _rounds++;
      _step = (_step + 1) % 4;
      if (_rounds == _target) {
        _checkpoint = true;
        _running = false;
      }
    });
    _phase.reset();
    if (_checkpoint) {
      unawaited(_keepAwake(false));
      _cue();
      _announce(
          'Checkpoint. $_rounds rounds complete. Breathe naturally. Continue for four more, or finish.');
    } else {
      _cue();
      _announce('${_spoken[_step]}. Round ${_rounds + 1} of $_target.');
      _phase.forward();
    }
  }

  void _start() {
    setState(() {
      if (_checkpoint) {
        _target += 4;
        _checkpoint = false;
      }
      _running = true;
      _started = true;
    });
    unawaited(_keepAwake(true));
    _cue();
    _announce('${_spoken[_step]}. Round ${_rounds + 1} of $_target.');
    _phase.forward();
  }

  void _pause() {
    if (!_running) return;
    _phase.stop();
    unawaited(_stopSound());
    setState(() => _running = false);
    unawaited(_keepAwake(false));
    _announce('Paused. Breathe naturally.');
  }

  void _reset() {
    _phase.stop();
    unawaited(_stopSound());
    setState(() {
      _running = false;
      _started = false;
      _checkpoint = false;
      _step = 0;
      _rounds = 0;
      _target = 4;
    });
    _phase.reset();
    unawaited(_keepAwake(false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _native.setMethodCallHandler(null);
    _phase.dispose();
    unawaited(_stopSound());
    unawaited(_keepAwake(false));
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await _native.invokeMethod<void>('openURL', url);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open the link. Please try again.')));
      }
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  void _settings() {
    _pause();
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (context) => StatefulBuilder(
            builder: (context, update) => Scaffold(
                  appBar: AppBar(title: const Text('Settings')),
                  body: SafeArea(
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: ListView(
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    const Text('Your practice',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 12),
                                    SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Sound'),
                                        subtitle: const Text(
                                            'A soft chime at each phase and checkpoint'),
                                        value: _sound,
                                        onChanged: (value) {
                                          setState(() => _sound = value);
                                          update(() {});
                                          _savePreferences();
                                          if (!value) _stopSound();
                                        }),
                                    SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Haptics'),
                                        subtitle: const Text(
                                            'Gentle taps, independent of sound'),
                                        value: _haptics,
                                        onChanged: (value) {
                                          setState(() => _haptics = value);
                                          update(() {});
                                          _savePreferences();
                                        }),
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                            icon: const Icon(
                                                Icons.volume_up_outlined),
                                            label: const Text('Test sound'),
                                            onPressed: () async {
                                              await _playSound(test: true);
                                              if (context.mounted) {
                                                update(() {});
                                              }
                                            })),
                                    const Text(
                                        'Uses media volume, including in Silent Mode. Sound plays through your current speaker or headphones.',
                                        style: TextStyle(color: _muted)),
                                    if (_audioError != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(_audioError!)),
                                    const SizedBox(height: 28),
                                    const Text('Free & open source',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    const Text(
                                        'A small breathing tool you can inspect, improve and share. No account, ads or subscriptions.'),
                                    const SizedBox(height: 12),
                                    const Text(
                                        'No session history, analytics or microphone access. Only your sound and haptics preferences are saved on this device.'),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                        onPressed: () => _open(_source),
                                        icon: const Icon(Icons.code),
                                        label: const Text(
                                            'View source on GitHub')),
                                    TextButton(
                                        onPressed: () => _open(
                                            '$_source/blob/main/PRIVACY.md'),
                                        child: const Text('Privacy policy')),
                                    TextButton(
                                        onPressed: () =>
                                            _open('$_source/issues'),
                                        child:
                                            const Text('Support & feedback')),
                                    TextButton(
                                        onPressed: () => showLicensePage(
                                            context: context,
                                            applicationName: 'Box Breathing',
                                            applicationVersion:
                                                '$_version ($_build)'),
                                        child:
                                            const Text('Open-source licenses')),
                                    const SizedBox(height: 20),
                                    Center(
                                        child: Text(
                                            'Version $_version · Build $_build',
                                            style: const TextStyle(
                                                color: _muted))),
                                    TextButton(
                                        onPressed: _copyDiagnostics,
                                        child: const Text('Copy diagnostics')),
                                  ])))),
                ))));
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final groupDone = _checkpoint ? 4 : _rounds % 4;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Box Breathing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            backgroundColor: _background,
            actions: [
              IconButton(
                  tooltip: 'Settings',
                  onPressed: _settings,
                  icon: const Icon(Icons.settings_outlined)),
            ]),
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(children: [
                              Text(
                                  _checkpoint
                                      ? 'A moment to check in'
                                      : 'A little space to breathe',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 8),
                              Text(
                                  _checkpoint
                                      ? 'Breathe naturally. Notice how you feel.'
                                      : 'Inhale · Hold · Exhale · Hold\n4 seconds each · 4 rounds · about 1 minute',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 15,
                                      height: 1.6)),
                              const SizedBox(height: 24),
                              AnimatedBuilder(
                                  animation: _phase,
                                  builder: (context, child) {
                                    final seconds = math.max(
                                        1, (4 * (1 - _phase.value)).ceil());
                                    final label = _checkpoint
                                        ? 'Complete'
                                        : !_started
                                            ? 'Ready'
                                            : !_running
                                                ? 'Paused'
                                                : _phases[_step];
                                    return Semantics(
                                        label: _checkpoint
                                            ? '$_rounds rounds complete'
                                            : !_started
                                                ? 'Ready to begin four rounds'
                                                : '${_running ? _spoken[_step] : "Paused"}. $seconds seconds. $_rounds completed rounds.',
                                        child: ExcludeSemantics(
                                            child: SizedBox(
                                                width: math.min(
                                                    constraints.maxWidth - 48,
                                                    320),
                                                height: math.min(
                                                    constraints.maxWidth - 48,
                                                    320),
                                                child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Positioned.fill(
                                                          child: CustomPaint(
                                                              painter: BoxBreathingPainter(
                                                                  progress: reduceMotion
                                                                      ? 0
                                                                      : _phase
                                                                          .value,
                                                                  currentStep:
                                                                      _step,
                                                                  stepColor:
                                                                      _accent,
                                                                  glowIntensity:
                                                                      reduceMotion
                                                                          ? 0
                                                                          : 0.2))),
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(52),
                                                          child: FittedBox(
                                                              fit: BoxFit
                                                                  .scaleDown,
                                                              child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(label,
                                                                        style: const TextStyle(
                                                                            color:
                                                                                _muted,
                                                                            fontSize:
                                                                                20)),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Text(
                                                                        _checkpoint
                                                                            ? '$_rounds'
                                                                            : !_started
                                                                                ? '4'
                                                                                : '$seconds',
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                68,
                                                                            height: 1.1,
                                                                            fontWeight: FontWeight.w300,
                                                                            fontFeatures: [
                                                                              FontFeature.tabularFigures()
                                                                            ])),
                                                                    if (_checkpoint ||
                                                                        !_started)
                                                                      Text(
                                                                          _checkpoint
                                                                              ? 'rounds complete'
                                                                              : 'rounds to unwind',
                                                                          style: const TextStyle(
                                                                              color: _muted,
                                                                              fontSize: 14)),
                                                                  ]))),
                                                    ]))));
                                  }),
                              const SizedBox(height: 20),
                              Semantics(
                                  label: '$_rounds of $_target rounds complete',
                                  child: ExcludeSemantics(
                                      child: Column(children: [
                                    Text(
                                        _checkpoint
                                            ? 'Checkpoint reached'
                                            : '$_rounds of $_target rounds complete',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ])),
                                    const SizedBox(height: 12),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                            4,
                                            (i) => Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4),
                                                width: 36,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                    color: i < groupDone
                                                        ? _accent
                                                        : const Color(
                                                            0xFF3B3B53),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3))))),
                                  ]))),
                              const SizedBox(height: 28),
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                      onPressed: _running ? _pause : _start,
                                      icon: Icon(_running
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded),
                                      label: Text(_checkpoint
                                          ? 'Continue for 4 more'
                                          : _running
                                              ? 'Pause'
                                              : _started
                                                  ? 'Resume'
                                                  : 'Begin 4 rounds'))),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: _started ? _reset : null,
                                  child: Text(_checkpoint
                                      ? 'Finish'
                                      : 'Reset session')),
                              const SizedBox(height: 16),
                              const Text(
                                  'Keep your breath gentle. If you feel uncomfortable or dizzy, stop and breathe normally.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      height: 1.5)),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                  onPressed: _settings,
                                  icon: const Icon(Icons.code, size: 18),
                                  label: const Text('Free & open source')),
                            ])))))));
  }
}
