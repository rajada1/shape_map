import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map_example/main.dart';

void _setSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectNoError(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}

void main() {
  testWidgets('controls fit a narrow phone layout', (tester) async {
    _setSize(tester, 360, 640);
    await tester.pumpWidget(const ShapeMapExampleApp());
    await tester.pump();
    _expectNoError(tester);
    for (final label in ['Replay', 'Reverse', 'Reset']) {
      await tester.tap(find.text(label));
      await tester.pump();
      _expectNoError(tester);
    }
  });

  testWidgets('controls fit a wide layout', (tester) async {
    _setSize(tester, 1280, 800);
    await tester.pumpWidget(const ShapeMapExampleApp());
    await tester.pump();
    _expectNoError(tester);
    await tester.tap(find.text('Replay'));
    await tester.pump();
    _expectNoError(tester);
  });
}
