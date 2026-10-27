import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:box_breathing_app/main.dart';
import 'package:box_breathing_app/box_painter.dart';

void main() {
  testWidgets('breathing phases, pause, restart and reset stay synchronized', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BoxBreathingApp());
    await tester.pump();
    BoxBreathingPainter painter() => tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter).whereType<BoxBreathingPainter>().single;
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(painter().currentStep, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(painter().currentStep, 2);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Pause'));
    await tester.pump();
    final pausedProgress = painter().progress;
    await tester.pump(const Duration(seconds: 5));
    expect(painter().currentStep, 2);
    expect(painter().progress, pausedProgress);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(painter().currentStep, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(painter().currentStep, 1);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(painter().currentStep, 0);
    expect(painter().progress, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(painter().currentStep, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
