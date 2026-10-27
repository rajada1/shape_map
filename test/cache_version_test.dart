import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/painters.dart';
import 'package:shape_map/src/rendering/transform.dart';

void main() {
  test('cache version increments when layout or border change', () {
    final cache = MapRenderCache();
    final map = ShapeMaps.southAmerica;
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

  test('small-map border picture is rebuilt after a resize', () {
    final cache = MapRenderCache();
    final map = ShapeMaps.southAmerica;
    cache.update(map, const Size(342, 400), BoxFit.contain, Alignment.center);
    cache.updateBorder(const Color(0xFFF3FBFE), 2);
    final firstPicture = cache.borderPicture;

    cache.update(map, const Size(600, 700), BoxFit.contain, Alignment.center);
    cache.updateBorder(const Color(0xFFF3FBFE), 2);

    expect(identical(cache.borderPicture, firstPicture), isFalse);
    cache.dispose();
  });

  testWidgets('resizing a small ShapeMap rebuilds its screen-space border', (
    tester,
  ) async {
    Widget build(Size size) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ShapeMap(
            map: ShapeMaps.southAmerica,
            animationDuration: Duration.zero,
          ),
        ),
      ),
    );

    RegionBorderPainter borderPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<RegionBorderPainter>()
        .single;

    await tester.pumpWidget(build(const Size(342, 400)));
    final first = borderPainter().cache.borderPicture;
    await tester.pumpWidget(build(const Size(600, 700)));
    final second = borderPainter().cache.borderPicture;
    expect(identical(first, second), isFalse);
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
            map: ShapeMaps.southAmerica,
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
