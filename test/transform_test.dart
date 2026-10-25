import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:shape_map/src/rendering/transform.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('contain transform is reversible', () {
    final transform = calculateTransform(
      ShapeMaps.southAmericaCountries,
      const Size(500, 500),
      BoxFit.contain,
      Alignment.center,
    );
    const source = Offset(215, 125);
    expect(transform.inverse(transform.forward(source)), source);
  });
}
