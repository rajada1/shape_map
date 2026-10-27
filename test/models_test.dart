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

  test(
    'focus maps keep the South America viewBox and expose country bounds',
    () {
      const expected = <String, int>{
        'AR': 24,
        'BO': 9,
        'BR': 27,
        'CL': 16,
        'CO': 33,
        'EC': 24,
        'GY': 10,
        'PE': 26,
        'PY': 18,
        'SR': 10,
        'UY': 19,
        'VE': 25,
      };
      for (final entry in expected.entries) {
        final map = ShapeMaps.southAmericaFocus(entry.key);
        expect(map.viewBox, ShapeMaps.southAmerica.viewBox);
        expect(map.focusBounds, isNotNull);
        final focusRegions = map.regions
            .where((region) => region.id.startsWith('${entry.key}-'))
            .toList();
        expect(focusRegions, hasLength(entry.value));
        expect(
          focusRegions.map((region) => region.id).toSet(),
          hasLength(entry.value),
        );
        for (final region in focusRegions) {
          expect(
            region.geometry.path.contains(region.markerAnchor),
            isTrue,
            reason: '${entry.key} ${region.id} ${region.markerAnchor}',
          );
        }
        final bounds = map.focusBounds!;
        for (final region in focusRegions) {
          expect(region.bounds.left, greaterThanOrEqualTo(bounds.left));
          expect(region.bounds.top, greaterThanOrEqualTo(bounds.top));
          expect(region.bounds.right, lessThanOrEqualTo(bounds.right));
          expect(region.bounds.bottom, lessThanOrEqualTo(bounds.bottom));
        }
        expect(map.regions.any((region) => region.id == 'GF'), isTrue);
      }
    },
  );

  test('focus maps expose the same camera region-fit API', () {
    final map = ShapeMaps.southAmericaFocus('BR');
    final region = map.regionById('BR-SP');
    expect(region, isNotNull);
    expect(region!.bounds.left, greaterThanOrEqualTo(map.focusBounds!.left));
    expect(region.bounds.top, greaterThanOrEqualTo(map.focusBounds!.top));
    expect(region.bounds.right, lessThanOrEqualTo(map.focusBounds!.right));
    expect(region.bounds.bottom, lessThanOrEqualTo(map.focusBounds!.bottom));
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
