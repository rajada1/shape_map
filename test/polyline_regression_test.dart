import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  // Regression: border polylines with only two points (a single segment) were
  // skipped by the shared path builder, dropping short border pieces.
  test('two-point border polylines are kept in the path', () {
    final line = MapPolyline.fromQuantized(
      lines: const [
        [0, 0, 40, 0],
      ],
      scale: 0.25,
    );
    final bounds = line.path.getBounds();
    expect(bounds.width, closeTo(10, 1e-9));
  });

  test('embedded maps keep every encoded border segment', () {
    for (final map in [
      ShapeMaps.world,
      ShapeMaps.latinAmerica,
      ShapeMaps.southAmerica,
      ShapeMaps.brazilStates,
    ]) {
      for (final border in [...map.innerBorders, ...map.outline]) {
        expect(
          border.path.computeMetrics().isNotEmpty,
          isTrue,
          reason: '${map.id} has an empty border polyline',
        );
      }
    }
  });
}
