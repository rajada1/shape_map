import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/painters.dart';
import 'package:shape_map/src/rendering/transform.dart';

void main() {
  test('cache version increments when layout or border change', () {
    final cache = MapRenderCache();
    final map = ShapeMaps.southAmericaCountries;
    cache.update(map, const Size(400, 400), BoxFit.contain, Alignment.center);
    cache.updateBorder(const Color(0xFFF3FBFE), 2);
    final v1 = cache.version;

    // Same inputs: no invalidation.
    cache.update(map, const Size(400, 400), BoxFit.contain, Alignment.center);
    cache.updateBorder(const Color(0xFFF3FBFE), 2);
    expect(cache.version, v1);

    // Same size, different alignment: must invalidate.
    cache.update(map, const Size(400, 400), BoxFit.contain, Alignment.topLeft);
    expect(cache.version, greaterThan(v1));
    cache.dispose();
  });

  testWidgets('changing alignment with the same size repaints the map', (
    tester,
  ) async {
    Widget build(Alignment alignment) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmericaCountries,
            alignment: alignment,
            animationDuration: Duration.zero,
          ),
        ),
      ),
    );

    RegionFillPainter fillPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<RegionFillPainter>()
        .single;

    await tester.pumpWidget(build(Alignment.center));
    final before = fillPainter();
    await tester.pumpWidget(build(Alignment.topLeft));
    final after = fillPainter();
    expect(after.shouldRepaint(before), isTrue);
  });
}
