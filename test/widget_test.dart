import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:box_breathing_app/main.dart';
import 'package:box_breathing_app/box_painter.dart';

void main() {
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.openinfra.boxBreathingApp/session'),
            (call) async {
      calls.add(call);
      if (call.method == 'info') return {'version': '1.0.0', 'build': '3'};
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
    await tester.ensureVisible(find.text('Version 1.0.0 · Build 3'));
    expect(find.text('Version 1.0.0 · Build 3'), findsOneWidget);
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
}
