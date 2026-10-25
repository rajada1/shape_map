import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('generated South America map has 13 unique regions and viewBox', () {
    final map = ShapeMaps.southAmericaCountries;
    expect(map.viewBox, const Size(342, 400));
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
    expect(map.viewBox, const Size(342, 330));
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
}
