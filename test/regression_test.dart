import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/markers.dart';
import 'package:shape_map/src/rendering/transform.dart';

void main() {
  test('models and styles compare by content', () {
    expect(
      const MapRegionData(value: 10, label: 'X'),
      const MapRegionData(value: 10, label: 'X'),
    );
    expect(
      const MapMarkerData(regionId: 'BR', value: 10),
      const MapMarkerData(regionId: 'BR', value: 10),
    );
    expect(const MarkerScale(), const MarkerScale());
    expect(const MarkerStyle(), const MarkerStyle());
    expect(const TooltipStyle(), const TooltipStyle());
    expect(const ShapeMapStyle(), const ShapeMapStyle());
  });

  test('generated map anchors preserve geographic orientation', () {
    Offset anchor(MapDefinition map, String id) =>
        map.regionById(id)!.markerAnchor;

    final brazil = ShapeMaps.brazilStates;
    expect(anchor(brazil, 'BR-RR').dy, lessThan(anchor(brazil, 'BR-RS').dy));
    expect(anchor(brazil, 'BR-AC').dx, lessThan(anchor(brazil, 'BR-PE').dx));

    final world = ShapeMaps.world;
    expect(anchor(world, 'GL').dy, lessThan(anchor(world, 'AR').dy));
    expect(anchor(world, 'NO').dy, lessThan(anchor(world, 'ZA').dy));
    expect(anchor(world, 'US').dx, lessThan(anchor(world, 'CN').dx));

    expect(
      anchor(ShapeMaps.southAmerica, 'VE').dy,
      lessThan(anchor(ShapeMaps.southAmerica, 'AR').dy),
    );
    expect(
      anchor(ShapeMaps.latinAmerica, 'MX').dy,
      lessThan(anchor(ShapeMaps.latinAmerica, 'CL').dy),
    );
  });

  test('marker cache does not create a painter for hidden labels', () {
    final cache = MarkerLayoutCache();
    cache.update(
      ShapeMaps.southAmerica,
      const [MapMarkerData(regionId: 'BR', value: 1, showLabel: false)],
      const MarkerStyle(),
      const {},
    );
    expect(cache.entries.single.textPainter, isNull);
    cache.dispose();
  });

  testWidgets('tooltip stays small and does not block map taps', (
    tester,
  ) async {
    final controller = ShapeMapController()..select('BR');
    MapRegion? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 400,
            child: ShapeMap(
              map: ShapeMaps.southAmerica,
              controller: controller,
              animationDuration: Duration.zero,
              data: const {'BR': MapRegionData(value: 620)},
              onRegionTap: (region) => tapped = region,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final mapFinder = find.byType(ShapeMap);
    final tooltipFinder = find.byKey(
      const ValueKey<String>('shape-map-tooltip'),
    );
    expect(tooltipFinder, findsOneWidget);
    expect(
      tester.getSize(tooltipFinder).width,
      lessThan(tester.getSize(mapFinder).width / 2),
    );
    expect(
      tester.getSize(tooltipFinder).height,
      lessThan(tester.getSize(mapFinder).height / 2),
    );

    final transform = calculateTransform(
      ShapeMaps.southAmerica,
      tester.getSize(mapFinder),
      BoxFit.contain,
      Alignment.center,
    );
    final peAnchor = ShapeMaps.southAmerica.regionById('PE')!.markerAnchor;
    await tester.tapAt(
      tester.getTopLeft(mapFinder) + transform.forward(peAnchor),
    );
    expect(tapped?.id, 'PE');
    controller.dispose();
  });

  testWidgets('tapping outside clears the current selection', (tester) async {
    final controller = ShapeMapController()..select('BR');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 400,
            child: ShapeMap(
              map: ShapeMaps.southAmerica,
              controller: controller,
              animationDuration: Duration.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(
      tester.getTopLeft(find.byType(ShapeMap)) + const Offset(1, 1),
    );
    expect(controller.selectedRegionId, isNull);
    controller.dispose();
  });

  testWidgets('equal data does not restart animation but changed data does', (
    tester,
  ) async {
    Widget map(Map<String, MapRegionData> data) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 342,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmerica,
            data: data,
            animationDuration: const Duration(milliseconds: 300),
          ),
        ),
      ),
    );
    await tester.pumpWidget(map({'BR': const MapRegionData(value: 1)}));
    await tester.pumpAndSettle();
    await tester.pumpWidget(map({'BR': const MapRegionData(value: 1)}));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(map({'BR': const MapRegionData(value: 2)}));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('duration zero disables data and marker animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 400,
            child: ShapeMap(
              map: ShapeMaps.southAmerica,
              data: const {'BR': MapRegionData(value: 1)},
              markers: const [
                MapMarkerData(regionId: 'BR', value: 1, diameter: 20),
              ],
              animationDuration: Duration.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
