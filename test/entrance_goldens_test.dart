import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

const _data = <String, MapRegionData>{
  'BR': MapRegionData(value: 9800),
  'AR': MapRegionData(value: 820),
  'PE': MapRegionData(value: 610),
  'CL': MapRegionData(value: 450),
  'BO': MapRegionData(value: 290),
  'PY': MapRegionData(value: 180),
  'EC': MapRegionData(value: 150),
  'UY': MapRegionData(value: 90),
};

const _markers = <MapMarkerData>[
  MapMarkerData(regionId: 'BR', value: 1, label: '9,8 mil', diameter: 66),
  MapMarkerData(regionId: 'AR', value: 1, label: '820', diameter: 38),
  MapMarkerData(regionId: 'PE', value: 1, label: '610', diameter: 36),
];

Future<void> _pumpAt(
  WidgetTester tester,
  ShapeMapEntranceStyle style,
  double value,
) async {
  tester.view.physicalSize = const Size(342, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final animation = AnimationController(
    vsync: const TestVSync(),
    duration: const Duration(seconds: 1),
    value: value,
  );
  addTearDown(animation.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 342,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmerica,
            data: _data,
            markers: _markers,
            animationDuration: Duration.zero,
            entrance: ShapeMapEntrance(style: style),
            entranceAnimation: animation,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final style in ShapeMapEntranceStyle.values) {
    testWidgets('entrance ${style.name} at 50%', (tester) async {
      await _pumpAt(tester, style, 0.5);
      await expectLater(
        find.byType(ShapeMap),
        matchesGoldenFile('goldens/entrance_${style.name}_50.png'),
      );
    });

    testWidgets('entrance ${style.name} at 0% paints nothing', (tester) async {
      await _pumpAt(tester, style, 0);
      await expectLater(
        find.byType(ShapeMap),
        matchesGoldenFile('goldens/entrance_empty.png'),
      );
    });
  }

  testWidgets('draw traces the outline at 25%', (tester) async {
    await _pumpAt(tester, ShapeMapEntranceStyle.draw, 0.25);
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/entrance_draw_25.png'),
    );
  });

  testWidgets('markers pop in during the final phase (90%)', (tester) async {
    await _pumpAt(tester, ShapeMapEntranceStyle.fade, 0.9);
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/entrance_markers_90.png'),
    );
  });
}
