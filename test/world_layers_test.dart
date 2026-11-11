import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('country layers share the world frame', () async {
    final world = ShapeMaps.world;
    expect(world.viewBox, const Size(1200, 790));
    for (final iso in ShapeMaps.focusCountries) {
      final layer = await ShapeMaps.loadCountryFocus(iso);
      expect(layer.viewBox, world.viewBox, reason: iso);
      final country = world.regionById(iso);
      expect(country, isNotNull, reason: iso);
      // The admin-1 layer sits where the world draws the country. Bounds are
      // compared with a tolerance because the two sources differ in detail.
      final slack = world.viewBox.longestSide * 0.02;
      final focus = layer.focusBounds!;
      expect(
        country!.bounds.inflate(slack).overlaps(focus),
        isTrue,
        reason: '$iso focus $focus vs country ${country.bounds}',
      );
    }
  });

  test('antimeridian countries keep fine detail on their main side', () async {
    for (final iso in ['FJ', 'NZ', 'US']) {
      final layer = await ShapeMaps.loadCountryFocus(iso);
      final primary = layer.primaryFocusBounds!;
      expect(primary.width, lessThan(layer.viewBox.width * 0.5), reason: iso);
      final vertices = layer.regions.fold<int>(
        0,
        (sum, region) =>
            sum +
            region.geometry.quantizedRings.fold<int>(
              0,
              (inner, ring) => inner + ring.length ~/ 2,
            ),
      );
      expect(vertices, greaterThan(100), reason: iso);
    }
  });

  test(
    'withDetail stacks a layer above the world without resetting ids',
    () async {
      final world = ShapeMaps.world;
      final merged = await ShapeMaps.loadWorldWithCountry('BR');
      expect(merged.viewBox, world.viewBox);
      expect(merged.focusRegionPrefix, 'BR-');
      expect(merged.regions.length, world.regions.length + 27);
      // The coarse country stays under its states, and states paint last.
      expect(merged.regionById('BR'), isNotNull);
      expect(merged.indexOf('BR-SP'), greaterThan(merged.indexOf('BR')));
      expect(merged.indexOf('AR'), lessThan(merged.indexOf('BR-AC')));
      expect(merged.outline.length, world.outline.length);
      expect(
        merged.innerBorders.length,
        world.innerBorders.length +
            (await ShapeMaps.loadCountryFocus('BR')).innerBorders.length,
      );
      // A tap inside São Paulo state resolves to the state, not the country.
      final sp = merged.regionById('BR-SP')!;
      expect(merged.hitTest(sp.markerAnchor)?.id, 'BR-SP');
      expect(
        identical(merged, await ShapeMaps.loadWorldWithCountry('br')),
        isTrue,
      );
      expect(ShapeMaps.worldWithCountryIfLoaded('BR'), same(merged));
    },
  );

  test('withDetail rejects a different viewBox', () {
    expect(
      () => ShapeMaps.world.withDetail(ShapeMaps.brazilStates),
      throwsArgumentError,
    );
  });

  testWidgets('camera survives swapping maps in the same viewBox', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    final merged = (await tester.runAsync(
      () => ShapeMaps.loadWorldWithCountry('BR'),
    ))!;
    Widget build(MapDefinition map) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: ShapeMap(
            map: map,
            cameraController: camera,
            zoomEnabled: true,
            maxScale: 32,
            animationDuration: Duration.zero,
            cameraAnimationDuration: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(ShapeMaps.world));
    camera.zoomToBounds(ShapeMaps.world.regionById('BR')!.bounds);
    await tester.pump();
    final scale = camera.scale;
    final pan = camera.pan;
    expect(scale, greaterThan(1));

    await tester.pumpWidget(build(merged));
    await tester.pump();
    expect(camera.scale, scale);
    expect(camera.pan, pan);
    expect(camera.viewBoxPointAt(const Offset(200, 150)), isNotNull);
    expect(camera.visibleViewBox, isNotNull);
    expect(camera.viewportSize, const Size(400, 300));

    // A different frame still resets the camera.
    await tester.pumpWidget(build(ShapeMaps.brazilStates));
    await tester.pump();
    expect(camera.scale, 1);
    expect(camera.pan, Offset.zero);
  });

  test('runtime catalog matches the generated maps', () async {
    final catalog = GeoCatalog.parse(
      File('assets/catalog/geo_names.json').readAsStringSync(),
    );
    // Every world region plus French Guiana, drawn inside France on the map.
    expect(catalog.countries, hasLength(ShapeMaps.world.regions.length + 1));
    expect(catalog.country('GF')!.hasFocus, isFalse);
    expect(catalog.country('GF')!.name('es'), 'Guayana Francesa');
    expect(catalog.country('br')!.name('pt'), 'Brasil');
    expect(catalog.country('BR')!.name('xx'), 'Brazil');
    expect(catalog.country('BR')!.hasFocus, isTrue);
    expect(catalog.country('AQ'), isNull);
    final focusCountries = catalog.countries
        .where((country) => country.hasFocus)
        .map((country) => country.iso2)
        .toSet();
    expect(focusCountries, ShapeMaps.focusCountries);
    for (final iso in ['BR', 'US', 'JP', 'GB']) {
      final layer = await ShapeMaps.loadCountryFocus(iso);
      final codes = catalog.subdivisions(iso).map((s) => s.code).toSet();
      expect(codes, layer.regions.map((r) => r.id).toSet(), reason: iso);
    }
    expect(catalog.subdivisions('AQ'), isEmpty);
    expect(catalog.subdivisionCount, greaterThan(4000));
  });
}
