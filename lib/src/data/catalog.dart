import 'package:flutter/services.dart';

import 'generated/brazil_states.g.dart';
import 'generated/country_focus_catalog.g.dart';
import 'generated/latin_america.g.dart';
import 'generated/south_america.g.dart';
import 'generated/south_america_focus_ar.g.dart';
import 'generated/south_america_focus_bo.g.dart';
import 'generated/south_america_focus_br.g.dart';
import 'generated/south_america_focus_cl.g.dart';
import 'generated/south_america_focus_co.g.dart';
import 'generated/south_america_focus_ec.g.dart';
import 'generated/south_america_focus_gy.g.dart';
import 'generated/south_america_focus_pe.g.dart';
import 'generated/south_america_focus_py.g.dart';
import 'generated/south_america_focus_sr.g.dart';
import 'generated/south_america_focus_uy.g.dart';
import 'generated/south_america_focus_ve.g.dart';
import 'generated/world.g.dart';
import 'codec.dart';
import 'models.dart';

/// Identifies a built-in map that can be preloaded.
enum ShapeMapId {
  world,
  latinAmerica,
  southAmerica,
  brazilStates,
  southAmericaFocusAr,
  southAmericaFocusBo,
  southAmericaFocusBr,
  southAmericaFocusCl,
  southAmericaFocusCo,
  southAmericaFocusEc,
  southAmericaFocusGy,
  southAmericaFocusPe,
  southAmericaFocusPy,
  southAmericaFocusSr,
  southAmericaFocusUy,
  southAmericaFocusVe,
}

/// Built-in map definitions generated from public geographic sources.
abstract final class ShapeMaps {
  ShapeMaps._();

  static final Map<String, MapDefinition> _countryFocusCache = {};
  static final Map<String, Future<MapDefinition>> _countryFocusLoads = {};
  static final Map<String, MapDefinition> _worldWithCountryCache = {};

  /// Map of countries and territories in Natural Earth 50m data.
  ///
  /// Mercator projection clipped to latitudes -60..84, viewBox 1200x790. The
  /// country layers from [loadCountryFocus] share this frame, so they can be
  /// drawn on top with [MapDefinition.withDetail] or [loadWorldWithCountry].
  static MapDefinition get world => generatedWorld;

  /// Map of 33 sovereign Latin American and Caribbean countries plus GF.
  static MapDefinition get latinAmerica => generatedLatinAmerica;

  /// Map of 13 South American regions, including French Guiana.
  static MapDefinition get southAmerica => generatedSouthAmerica;

  /// Map of the 27 Brazilian federative units.
  static MapDefinition get brazilStates => generatedBrazilStates;

  /// ISO alpha-2 countries with a generated country-only admin-1 focus.
  static Set<String> get focusCountries => generatedCountryFocusCountries;

  /// Whether a country has a generated country-only focus map.
  static bool hasFocus(String countryIso) =>
      focusCountries.contains(_normalizeCountryIso(countryIso));

  /// Loads a country's admin-1 layer from this package's SMAP asset.
  ///
  /// The asset is decoded in an isolate and cached by ISO alpha-2 code. The
  /// returned map contains only that country's admin-1 regions, uses a focus
  /// prefix such as `US-` for camera fitting, and is expressed in the same
  /// viewBox as [world], so it can be drawn above the world map.
  static Future<MapDefinition> loadCountryFocus(String countryIso) {
    final iso = _requireFocusCountry(countryIso);
    final cached = _countryFocusCache[iso];
    if (cached != null) return Future.value(cached);
    return _countryFocusLoads[iso] ??= _loadCountryFocus(iso);
  }

  /// The world map with [countryIso]'s admin-1 regions drawn on top.
  ///
  /// Keeps every other country visible, so a camera zoom from the world into
  /// the country is continuous. The result is cached per country and shares
  /// the [world] viewBox, which lets [ShapeMap] keep its camera when swapping
  /// between [world] and this map. See [MapDefinition.withDetail].
  static Future<MapDefinition> loadWorldWithCountry(String countryIso) async {
    final iso = _requireFocusCountry(countryIso);
    final cached = _worldWithCountryCache[iso];
    if (cached != null) return cached;
    final results = await Future.wait([
      preloadGeneratedWorld(),
      loadCountryFocus(iso),
    ]);
    return _worldWithCountryCache[iso] ??= results[0].withDetail(
      results[1],
      id: 'worldWith$iso',
    );
  }

  /// Returns the cached result of [loadWorldWithCountry], or null before it
  /// has been loaded.
  static MapDefinition? worldWithCountryIfLoaded(String countryIso) =>
      _worldWithCountryCache[_normalizeCountryIso(countryIso)];

  /// Preloads a country-only focus map and retains it in the package cache.
  static Future<void> preloadCountryFocus(String countryIso) async {
    await loadCountryFocus(countryIso);
  }

  static Future<MapDefinition> _loadCountryFocus(String iso) async {
    try {
      final bytes = await rootBundle.load(
        'packages/shape_map/assets/maps/country_focus/$iso.smap',
      );
      final world = await preloadGeneratedWorld();
      final map = await ShapeMapData.decode(
        bytes,
        id: 'countryFocus$iso',
        focusRegionPrefix: '$iso-',
        mercatorLatitudes: world.mercatorLatitudes,
      );
      _countryFocusCache[iso] = map;
      return map;
    } finally {
      _countryFocusLoads.remove(iso);
    }
  }

  static String _normalizeCountryIso(String countryIso) =>
      countryIso.trim().toUpperCase();

  static String _requireFocusCountry(String countryIso) {
    final iso = _normalizeCountryIso(countryIso);
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(iso) || !hasFocus(iso)) {
      throw ArgumentError.value(
        countryIso,
        'countryIso',
        'Expected an ISO alpha-2 country with a generated admin-1 focus.',
      );
    }
    return iso;
  }

  /// Map of one South American country's admin-1 regions plus country context.
  ///
  /// [countryIso] is one of AR, BO, BR, CL, CO, EC, GY, PE, PY, SR, UY, VE.
  /// Each focus map keeps the [southAmerica] viewBox and projection. Its
  /// [MapDefinition.focusBounds] encloses the whole selected country.
  static MapDefinition southAmericaFocus(String countryIso) {
    return switch (countryIso.toUpperCase()) {
      'AR' => generatedSouthAmericaFocusAr,
      'BO' => generatedSouthAmericaFocusBo,
      'BR' => generatedSouthAmericaFocusBr,
      'CL' => generatedSouthAmericaFocusCl,
      'CO' => generatedSouthAmericaFocusCo,
      'EC' => generatedSouthAmericaFocusEc,
      'GY' => generatedSouthAmericaFocusGy,
      'PE' => generatedSouthAmericaFocusPe,
      'PY' => generatedSouthAmericaFocusPy,
      'SR' => generatedSouthAmericaFocusSr,
      'UY' => generatedSouthAmericaFocusUy,
      'VE' => generatedSouthAmericaFocusVe,
      _ => throw ArgumentError.value(
        countryIso,
        'countryIso',
        'Expected a supported South American ISO alpha-2 code.',
      ),
    };
  }

  /// Preloads one legacy South America focus map without synchronously decoding it.
  static Future<void> preloadFocus(String countryIso) async {
    final id = switch (countryIso.toUpperCase()) {
      'AR' => ShapeMapId.southAmericaFocusAr,
      'BO' => ShapeMapId.southAmericaFocusBo,
      'BR' => ShapeMapId.southAmericaFocusBr,
      'CL' => ShapeMapId.southAmericaFocusCl,
      'CO' => ShapeMapId.southAmericaFocusCo,
      'EC' => ShapeMapId.southAmericaFocusEc,
      'GY' => ShapeMapId.southAmericaFocusGy,
      'PE' => ShapeMapId.southAmericaFocusPe,
      'PY' => ShapeMapId.southAmericaFocusPy,
      'SR' => ShapeMapId.southAmericaFocusSr,
      'UY' => ShapeMapId.southAmericaFocusUy,
      'VE' => ShapeMapId.southAmericaFocusVe,
      _ => throw ArgumentError.value(
        countryIso,
        'countryIso',
        'Expected a supported South American ISO alpha-2 code.',
      ),
    };
    await preload([id]);
  }

  /// Preloads selected built-in maps without synchronously decoding them.
  ///
  /// When [maps] is omitted, all built-in maps are decoded concurrently in
  /// worker isolates. Synchronous getters remain available as a fallback.
  static Future<void> preload([Iterable<ShapeMapId>? maps]) async {
    final selected = maps?.toSet() ?? ShapeMapId.values.toSet();
    await Future.wait([
      if (selected.contains(ShapeMapId.world)) preloadGeneratedWorld(),
      if (selected.contains(ShapeMapId.latinAmerica))
        preloadGeneratedLatinAmerica(),
      if (selected.contains(ShapeMapId.southAmerica))
        preloadGeneratedSouthAmerica(),
      if (selected.contains(ShapeMapId.brazilStates))
        preloadGeneratedBrazilStates(),
      if (selected.contains(ShapeMapId.southAmericaFocusAr))
        preloadGeneratedSouthAmericaFocusAr(),
      if (selected.contains(ShapeMapId.southAmericaFocusBo))
        preloadGeneratedSouthAmericaFocusBo(),
      if (selected.contains(ShapeMapId.southAmericaFocusBr))
        preloadGeneratedSouthAmericaFocusBr(),
      if (selected.contains(ShapeMapId.southAmericaFocusCl))
        preloadGeneratedSouthAmericaFocusCl(),
      if (selected.contains(ShapeMapId.southAmericaFocusCo))
        preloadGeneratedSouthAmericaFocusCo(),
      if (selected.contains(ShapeMapId.southAmericaFocusEc))
        preloadGeneratedSouthAmericaFocusEc(),
      if (selected.contains(ShapeMapId.southAmericaFocusGy))
        preloadGeneratedSouthAmericaFocusGy(),
      if (selected.contains(ShapeMapId.southAmericaFocusPe))
        preloadGeneratedSouthAmericaFocusPe(),
      if (selected.contains(ShapeMapId.southAmericaFocusPy))
        preloadGeneratedSouthAmericaFocusPy(),
      if (selected.contains(ShapeMapId.southAmericaFocusSr))
        preloadGeneratedSouthAmericaFocusSr(),
      if (selected.contains(ShapeMapId.southAmericaFocusUy))
        preloadGeneratedSouthAmericaFocusUy(),
      if (selected.contains(ShapeMapId.southAmericaFocusVe))
        preloadGeneratedSouthAmericaFocusVe(),
    ]);
  }

  /// Deprecated alias for [southAmerica].
  @Deprecated('Use ShapeMaps.southAmerica')
  static MapDefinition get southAmericaCountries => southAmerica;
}
