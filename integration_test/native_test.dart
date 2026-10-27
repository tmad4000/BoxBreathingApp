import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:box_breathing_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> screenshot(String name) async {
    // Native screenshots must wait for the compositor, beyond widget settling.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await binding.takeScreenshot(name);
  }

  const channel = MethodChannel('com.openinfra.boxBreathingApp/session');
  testWidgets('native media sound, preferences, version and keep-awake',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await screenshot('box-ready');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await screenshot('box-settings');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final original = await channel.invokeMapMethod<String, dynamic>('info');
    expect(original!['version'], '1.0.0');
    expect(original['build'], isNotEmpty);
    expect(original['idleTimerDisabled'], false);
    final sound = await rootBundle.load('assets/audio/chime.wav');
    expect(sound.lengthInBytes, greaterThan(1000));
    await channel.invokeMethod<void>('playSound',
        sound.buffer.asUint8List(sound.offsetInBytes, sound.lengthInBytes));
    final playing = await channel.invokeMapMethod<String, dynamic>('info');
    expect(playing!['audioCategory'], 'AVAudioSessionCategoryPlayback');
    expect(playing['soundPlaying'], true);
    expect(playing['audioRoute'], isNotEmpty);
    await channel.invokeMethod<void>('stopSound');
    expect(
        (await channel
            .invokeMapMethod<String, dynamic>('info'))!['soundPlaying'],
        false);
    await channel.invokeMethod<void>(
        'savePreferences', {'soundEnabled': false, 'hapticsEnabled': true});
    final saved = await channel.invokeMapMethod<String, dynamic>('info');
    expect(saved!['soundEnabled'], false);
    expect(saved['hapticsEnabled'], true);
    await channel.invokeMethod<void>('savePreferences', {
      'soundEnabled': original['soundEnabled'],
      'hapticsEnabled': original['hapticsEnabled']
    });
    await channel.invokeMethod<void>('keepAwake', true);
    expect(
        (await channel
            .invokeMapMethod<String, dynamic>('info'))!['idleTimerDisabled'],
        true);
    await channel.invokeMethod<void>('keepAwake', false);
    await expectLater(
        channel.invokeMethod<void>('openURL', 'http://invalid.example/'),
        throwsA(isA<PlatformException>()));
    await tester.tap(find.text('Begin 4 rounds'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await screenshot('box-practice');
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 90));
    expect(find.text('Checkpoint reached'), findsOneWidget);
    await screenshot('box-checkpoint');
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    for (final event in ['routeLoss', 'interruption']) {
      await tester
          .tap(find.text(event == 'routeLoss' ? 'Begin 4 rounds' : 'Resume'));
      await tester.pump();
      await channel.invokeMethod<void>('debugAudioEvent', event);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);
      final paused = await channel.invokeMapMethod<String, dynamic>('info');
      expect(paused!['idleTimerDisabled'], false);
      expect(paused['soundPlaying'], false);
    }
  });
}
