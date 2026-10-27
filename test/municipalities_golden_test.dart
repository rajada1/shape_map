import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

/// Visual baseline for the optional 5,570-municipality dataset, which uses the
/// large-map rendering path (canvas transform, color batching, border picture
/// without union clip). Skipped when the example asset is not present.
void main() {
  final asset = File('example/assets/maps/brazil_municipalities.smap');

  testWidgets('Brazil municipalities layout', (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final map = ShapeMapData.decodeSync(asset.readAsBytesSync());
    const palette = [
      Color(0xFFFFEDE3),
      Color(0xFFFFDBC9),
      Color(0xFFF7B595),
      Color(0xFFE48A5F),
      Color(0xFFC04F00),
    ];
    final data = {
      for (final region in map.regions)
        region.id: MapRegionData(
          fill: palette[region.id.hashCode.abs() % palette.length],
        ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 900,
            height: 1000,
            child: ShapeMap(
              map: map,
              data: data,
              animationDuration: Duration.zero,
              style: const ShapeMapStyle(borderWidth: 0.5),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/brazil_municipalities.png'),
    );
  }, skip: !asset.existsSync());
}
