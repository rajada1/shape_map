import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('generated South America map has 13 unique regions and viewBox', () {
    final map = ShapeMaps.southAmerica;
    expect(map.viewBox, const Size(820, 1040));
    expect(map.regions, hasLength(13));
    expect(map.regions.map((region) => region.id).toSet(), hasLength(13));
    for (final region in map.regions) {
      expect(
        region.geometry.path.contains(region.markerAnchor),
        isTrue,
        reason: '${region.id} ${region.bounds} ${region.markerAnchor}',
      );
    }
  });

  test('generated Brazil map has 27 UFs including DF', () {
    final map = ShapeMaps.brazilStates;
    expect(map.viewBox, const Size(900, 1000));
    expect(map.regions, hasLength(27));
    expect(map.regions.map((region) => region.id).toSet(), hasLength(27));
    expect(map.regions.any((region) => region.id == 'BR-DF'), isTrue);
    for (final region in map.regions) {
      expect(
        region.geometry.path.contains(region.markerAnchor),
        isTrue,
        reason: '${region.id} ${region.bounds} ${region.markerAnchor}',
      );
    }
  });

  test('built-in country catalogs have valid IDs and coherent bounds', () {
    for (final map in [
      ShapeMaps.world,
      ShapeMaps.latinAmerica,
      ShapeMaps.southAmerica,
    ]) {
      expect(
        map.regions.map((region) => region.id).toSet(),
        hasLength(map.regions.length),
      );
      final viewBounds = Offset.zero & map.viewBox;
      for (final region in map.regions) {
        expect(RegExp(r'^[A-Z]{2}$').hasMatch(region.id), isTrue);
        expect(viewBounds.contains(region.bounds.topLeft), isTrue);
        expect(viewBounds.contains(region.bounds.bottomRight), isTrue);
        expect(region.geometry.path.contains(region.markerAnchor), isTrue);
      }
    }
  });

  test('marker scale clamps and interpolates linearly', () {
    const scale = MarkerScale(
      minValue: 10,
      maxValue: 20,
      minDiameter: 10,
      maxDiameter: 30,
    );
    expect(scale.diameterFor(10), 10);
    expect(scale.diameterFor(15), 20);
    expect(scale.diameterFor(100), 30);
  });

  test('warmUp materializes region and border paths cooperatively', () async {
    final regionGeometry = MapGeometry.fromQuantized(
      rings: const [
        [0, 0, 10, 0, 10, 10, 0, 10],
      ],
      scale: 1,
    );
    final border = MapPolyline.fromQuantized(
      lines: const [
        [0, 0, 10, 10],
      ],
      scale: 1,
    );
    final map = MapDefinition(
      id: 'warm-up',
      viewBox: const Size(10, 10),
      regions: [
        MapRegion(
          id: 'A',
          name: 'A',
          geometry: regionGeometry,
          markerAnchor: const Offset(5, 5),
        ),
      ],
      innerBorders: [border],
    );
    expect(regionGeometry.isMaterialized, isFalse);
    expect(border.isMaterialized, isFalse);
    await map.warmUp(chunkSize: 1);
    expect(regionGeometry.isMaterialized, isTrue);
    expect(border.isMaterialized, isTrue);
    expect(map.hitTest(const Offset(5, 5))?.id, 'A');
  });
}
