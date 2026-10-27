import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  testWidgets('selected Brazil state after zoom', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = ShapeMapCameraController();
    final selection = ShapeMapController()..select('BR-SP');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 900,
            height: 1000,
            child: ShapeMap(
              map: ShapeMaps.brazilStates,
              controller: selection,
              cameraController: camera,
              animationDuration: Duration.zero,
              cameraAnimationDuration: Duration.zero,
              style: const ShapeMapStyle(
                selectedColor: Color(0xFFFF9A76),
                selectedBorderColor: Color(0xFF8A2B00),
                selectedBorderWidth: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    camera.zoomTo(3, duration: Duration.zero);
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/camera_brazil_states_zoom.png'),
    );
    selection.dispose();
    camera.dispose();
  });

  testWidgets('municipalities keep a thin border after zoom', (tester) async {
    final file = File('example/assets/maps/brazil_municipalities.smap');
    if (!file.existsSync()) return;
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final map = ShapeMapData.decodeSync(file.readAsBytesSync());
    final camera = ShapeMapCameraController();
    final selection = ShapeMapController()..select('BR-3550308');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 900,
            height: 1000,
            child: ShapeMap(
              map: map,
              controller: selection,
              cameraController: camera,
              animationDuration: Duration.zero,
              cameraAnimationDuration: Duration.zero,
              style: const ShapeMapStyle(
                borderWidth: 0.5,
                selectedColor: Color(0xFFFF9A76),
                selectedBorderColor: Color(0xFF8A2B00),
                selectedBorderWidth: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    camera.zoomToRegion('BR-3550308', duration: Duration.zero);
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/camera_municipalities_zoom.png'),
    );
    selection.dispose();
    camera.dispose();
  });
}
