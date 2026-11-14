import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:box_breathing_app/main.dart';
import 'package:box_breathing_app/box_painter.dart';
import 'package:box_breathing_app/path_painter.dart';

void main() {
  late List<MethodCall> calls;
  String? copiedDiagnostics;
  bool audioFails = false;
  bool savedPath = false;
  setUp(() {
    calls = [];
    copiedDiagnostics = null;
    audioFails = false;
    savedPath = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedDiagnostics = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.openinfra.boxBreathingApp/session'),
            (call) async {
      calls.add(call);
      if (call.method == 'playSound' && audioFails) {
        throw PlatformException(code: 'audioUnavailable');
      }
      if (call.method == 'info') {
        return {'version': '1.0.0', 'build': '3', 'pathGuide': savedPath};
      }
      return null;
    });
  });
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BoxBreathingApp());
    await tester.pump();
  }

  BoxBreathingPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<BoxBreathingPainter>()
      .single;
  Iterable<BreathPathPainter> pathPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<BreathPathPainter>();
  Iterable<BoxBreathingPainter> boxPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<BoxBreathingPainter>();
  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump();
  }

  Future<void> phases(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4001));
      await tester.pump();
    }
  }

  testWidgets('full rounds stop at four and continuation retains the total',
      (tester) async {
    await launch(tester);
    expect(find.text('Ready'), findsOneWidget);
    await tap(tester, 'Begin 4 rounds');
    await phases(tester, 3);
    expect(find.text('0 of 4 rounds complete'), findsOneWidget);
    await phases(tester, 1);
    expect(find.text('1 of 4 rounds complete'), findsOneWidget);
    await phases(tester, 12);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Checkpoint reached'), findsOneWidget);
    expect(
        calls.lastWhere((call) => call.method == 'keepAwake').arguments, false);
    await phases(tester, 8);
    expect(find.text('Checkpoint reached'), findsOneWidget);
    await tap(tester, 'Continue for 4 more');
    expect(find.text('4 of 8 rounds complete'), findsOneWidget);
    await phases(tester, 16);
    expect(find.text('8'), findsOneWidget);
    await tap(tester, 'Finish');
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('0 of 4 rounds complete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pause and background preserve fractional phase position',
      (tester) async {
    await launch(tester);
    await tap(tester, 'Begin 4 rounds');
    await phases(tester, 1);
    await tester.pump(const Duration(milliseconds: 1500));
    await tap(tester, 'Pause');
    final progress = painter(tester).progress;
    expect(painter(tester).currentStep, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(painter(tester).progress, progress);
    expect(
        calls.lastWhere((call) => call.method == 'keepAwake').arguments, false);
    await tap(tester, 'Resume');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2501));
    await tester.pump();
    expect(painter(tester).currentStep, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(
        calls.lastWhere((call) => call.method == 'keepAwake').arguments, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    await tap(tester, 'Reset session');
    expect(find.text('Ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small screen, large type and reduced motion remain usable',
      (tester) async {
    await launch(tester);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: const MediaQuery(
            data: MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2),
                disableAnimations: true),
            child: BreathingScreen())));
    await tester.pump();
    await tap(tester, 'Begin 4 rounds');
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).progress, 0);
    expect(find.byTooltip('Settings'), findsOneWidget);
    await tap(tester, 'Pause');
    await tap(tester, 'Reset session');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Settings pauses practice, exposes version and tests sound independently',
      (tester) async {
    await launch(tester);
    await tap(tester, 'Begin 4 rounds');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Sound'), findsOneWidget);
    expect(
        calls.lastWhere((call) => call.method == 'keepAwake').arguments, false);
    await tap(tester, 'Sound');
    await tester.pumpAndSettle();
    final preferences = calls
        .lastWhere((call) => call.method == 'savePreferences')
        .arguments as Map;
    expect(preferences['soundEnabled'], false);
    expect(preferences['hapticsEnabled'], true);
    final before = calls.where((call) => call.method == 'playSound').length;
    await tap(tester, 'Test sound');
    await tester.pumpAndSettle();
    expect(
        calls.where((call) => call.method == 'playSound').length, before + 1);
    await tester.scrollUntilVisible(
      find.text('Version 1.0.0 · Build 3'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Version 1.0.0 · Build 3'));
    expect(find.text('Version 1.0.0 · Build 3'), findsOneWidget);
    await tap(tester, 'Copy diagnostics');
    await tester.pumpAndSettle();
    final snapshot = jsonDecode(copiedDiagnostics!) as Map<String, dynamic>;
    expect(snapshot['schemaVersion'], 1);
    expect(snapshot['appVersion'], '1.0.0');
    expect(snapshot['buildNumber'], '3');
    expect(snapshot['state'], 'paused');
    expect(snapshot['soundEnabled'], false);
    expect(snapshot['completedRounds'], 0);
    expect(snapshot.containsKey('history'), false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    await tap(tester, 'Resume');
    await tester.pump();
    expect(
        calls.where((call) => call.method == 'playSound').length, before + 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('system Reduce Motion never accelerates the breath clock',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    await tap(tester, 'Begin 4 rounds');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(painter(tester).currentStep, 0);
    await tester.pump(const Duration(milliseconds: 3001));
    await tester.pump();
    expect(painter(tester).currentStep, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('unavailable sound has an honest visible error', (tester) async {
    await launch(tester);
    audioFails = true;
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tap(tester, 'Test sound');
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Sound could not play. Check your output device and volume, then test again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('path geometry follows a 4-4-4-4 box breath', () {
    const box = [4.0, 4.0, 4.0, 4.0];
    final levels = <double, double>{
      0.0: 0.0,
      1.0: 0.25,
      2.0: 0.5,
      4.0: 1.0,
      6.0: 1.0,
      8.0: 1.0,
      10.0: 0.5,
      12.0: 0.0,
      14.0: 0.0,
      16.0: 0.0,
      18.0: 0.5,
    };
    for (final entry in levels.entries) {
      expect(
        breathLevel(entry.key, box),
        closeTo(entry.value, 1e-9),
        reason: 'level at ${entry.key}s',
      );
    }
    expect(breathElapsed(0, 0, box), 0);
    expect(breathElapsed(2, 0.5, box), 10);
    expect(breathLevel(15, const [4.0, 7.0, 8.0, 1.0]), closeTo(0.5, 1e-9));
    final painter = BreathPathPainter(
      elapsed: 2,
      durations: box,
      lineColor: Colors.white,
      ballColor: Colors.white,
      label: 'Inhale',
      detail: '2',
      detailColor: Colors.white,
    );
    const size = Size(400, 200);
    final ball = painter.ballOffset(size);
    expect(ball.dx, closeTo(400 * BreathPathPainter.ballFraction, 1e-9));
    final top = BreathPathPainter.topFor(size);
    final bottom = BreathPathPainter.bottomFor(size);
    expect(ball.dy, closeTo((top + bottom) / 2, 1e-9));
  });
  testWidgets('Guide style switches between box and path and is saved',
      (tester) async {
    await launch(tester);
    expect(boxPainters(tester), hasLength(1));
    expect(pathPainters(tester), isEmpty);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Guide style'), findsOneWidget);
    await tap(tester, 'Path');
    await tester.pumpAndSettle();
    final saved = calls
        .lastWhere((call) => call.method == 'savePreferences')
        .arguments as Map;
    expect(saved['pathGuide'], true);
    expect(saved['soundEnabled'], true);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(boxPainters(tester), isEmpty);
    expect(pathPainters(tester), hasLength(1));
    await tap(tester, 'Begin 4 rounds');
    await phases(tester, 1);
    await tester.pump(const Duration(milliseconds: 2000));
    final path = pathPainters(tester).single;
    expect(path.durations, [4.0, 4.0, 4.0, 4.0]);
    expect(path.elapsed, closeTo(6, 0.05));
    expect(path.label, 'Hold');
    expect(find.text('0 of 4 rounds complete'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tap(tester, 'Box');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(boxPainters(tester), hasLength(1));
    expect(pathPainters(tester), isEmpty);
    expect(painter(tester).currentStep, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a saved path guide is restored at launch', (tester) async {
    savedPath = true;
    await launch(tester);
    await tester.pump();
    expect(pathPainters(tester), hasLength(1));
    expect(pathPainters(tester).single.label, 'Ready');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
