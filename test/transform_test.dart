import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:shape_map/src/rendering/transform.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('contain transform is reversible', () {
    final transform = calculateTransform(
      ShapeMaps.southAmerica,
      const Size(500, 500),
      BoxFit.contain,
      Alignment.center,
    );
    const source = Offset(300, 400);
    final actual = transform.inverse(transform.forward(source));
    expect(actual.dx, closeTo(source.dx, 0.000001));
    expect(actual.dy, closeTo(source.dy, 0.000001));
  });

  test('spatial hit-test returns every built-in region anchor', () {
    for (final map in [ShapeMaps.southAmerica, ShapeMaps.brazilStates]) {
      for (final region in map.regions) {
        expect(map.hitTest(region.markerAnchor)?.id, region.id);
      }
    }
  });
}
