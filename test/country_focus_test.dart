import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

Map<String, dynamic> _catalog() =>
    jsonDecode(File('catalog/geo_catalog.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('country focus catalog exposes non-South-American examples', () {
    for (final iso in ['US', 'FR', 'IN', 'JP', 'ZA', 'AU']) {
      expect(ShapeMaps.hasFocus(iso), isTrue, reason: iso);
      expect(ShapeMaps.hasFocus(iso.toLowerCase()), isTrue, reason: iso);
    }
    expect(ShapeMaps.hasFocus('AQ'), isFalse);
    expect(ShapeMaps.focusCountries, contains('BR'));
  });

  test(
    'country-only focus maps load with bounds, unique IDs and anchors',
    () async {
      for (final iso in ['US', 'FR', 'IN', 'JP', 'ZA', 'AU']) {
        final map = await ShapeMaps.loadCountryFocus(iso);
        expect(map.focusRegionPrefix, '$iso-');
        expect(map.focusBounds, isNotNull, reason: iso);
        expect(map.regions, isNotEmpty, reason: iso);
        expect(
          map.regions.map((region) => region.id).toSet(),
          hasLength(map.regions.length),
          reason: iso,
        );
        for (final region in map.regions) {
          expect(region.id.startsWith('$iso-'), isTrue, reason: region.id);
          expect(
            region.geometry.path.contains(region.markerAnchor),
            isTrue,
            reason: '$iso ${region.id} ${region.markerAnchor}',
          );
        }
      }
    },
  );

  test(
    'country focus loading is cached after the first isolate decode',
    () async {
      await ShapeMaps.preloadCountryFocus('JP');
      final loaded = await ShapeMaps.loadCountryFocus('JP');
      final loadedAgain = await ShapeMaps.loadCountryFocus('JP');
      expect(identical(loaded, loadedAgain), isTrue);
    },
  );

  test('Brazil country focus keeps the 27 IBGE federative units', () async {
    final map = await ShapeMaps.loadCountryFocus('BR');
    expect(map.regions, hasLength(27));
    expect(map.regions.map((region) => region.id).toSet(), hasLength(27));
    expect(map.regionById('BR-DF'), isNotNull);
  });

  test('legacy South America focus API remains compatible', () async {
    await ShapeMaps.preloadFocus('AR');
    final map = ShapeMaps.southAmericaFocus('AR');
    expect(map.focusBounds, isNotNull);
    expect(map.regionById('AR-B'), isNotNull);
  });

  test('catalog subdivisions and generated focus maps stay in sync', () async {
    final catalog = _catalog();
    final countries = (catalog['countries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final subdivisions = (catalog['subdivisions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final catalogFocusCountries = countries
        .where((country) => country['has_focus'] == true)
        .map((country) => country['iso2'] as String)
        .toSet();
    expect(catalogFocusCountries, equals(ShapeMaps.focusCountries));

    final catalogCodesByCountry = <String, Set<String>>{};
    for (final subdivision in subdivisions) {
      final country = subdivision['country_iso'] as String;
      (catalogCodesByCountry[country] ??= <String>{}).add(
        subdivision['code'] as String,
      );
    }
    for (final iso in ShapeMaps.focusCountries) {
      final map = await ShapeMaps.loadCountryFocus(iso);
      expect(
        map.regions.map((region) => region.id).toSet(),
        equals(catalogCodesByCountry[iso]),
        reason: iso,
      );
    }
  });

  test('catalog rejects duplicate codes and unsupported country metadata', () {
    final catalog = _catalog();
    final countries = (catalog['countries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final subdivisions = (catalog['subdivisions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    const regions = {
      'south_america',
      'central_america',
      'caribbean',
      'north_america',
      'europe',
      'asia',
      'africa',
      'oceania',
    };
    final iso3 = countries.map((country) => country['iso3'] as String).toSet();
    final codes = subdivisions
        .map((subdivision) => subdivision['code'] as String)
        .toSet();

    expect(iso3, hasLength(countries.length));
    expect(
      countries.every(
        (country) =>
            RegExp(r'^[A-Z]{2}$').hasMatch(country['iso2'] as String) &&
            RegExp(r'^[A-Z]{3}$').hasMatch(country['iso3'] as String) &&
            regions.contains(country['region']),
      ),
      isTrue,
    );
    expect(codes, hasLength(subdivisions.length));
    expect(
      subdivisions.every(
        (subdivision) => RegExp(
          r'^[A-Z]{2}-[A-Z0-9]{1,3}$',
        ).hasMatch(subdivision['code'] as String),
      ),
      isTrue,
    );
  });

  test('duplicate ISO admin-1 codes preserve the canonical owners', () {
    final catalog = _catalog();
    final subdivisions = (catalog['subdivisions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? find(String code) => subdivisions.firstWhere(
      (subdivision) => subdivision['code'] == code,
      orElse: () => <String, dynamic>{},
    );

    final newSouthWales = find('AU-NSW');
    expect(newSouthWales?['name_en'], 'New South Wales');
    expect(
      subdivisions.any(
        (subdivision) => subdivision['name_en'] == 'Lord Howe Island',
      ),
      isFalse,
    );

    final almatyCity = find('KZ-ALA');
    final almatyRegion = find('KZ-ALM');
    expect(almatyCity?['source_codes'], contains('KAZ-4829'));
    expect(almatyRegion?['source_codes'], contains('KAZ-3207'));

    expect(find('RU-KR')?['name_en'], 'Karelia');
    expect(find('RU-43')?['name_en'], 'Autonomous Republic of Crimea');
    expect(find('PH-MNL')?['name_en'], 'Metro Manila');

    final report =
        jsonDecode(File('tool/maps/report.json').readAsStringSync())
            as Map<String, dynamic>;
    final consistency = report['consistency'] as Map<String, dynamic>;
    expect(consistency['resolvedDuplicateCodeCount'], 59);
    expect(consistency['primaryIsoCodeReplacements'], isEmpty);
  });
}
