import 'models.dart';
import 'generated/brazil_states.g.dart';
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

  /// Map of countries and territories in Natural Earth 50m data.
  static MapDefinition get world => generatedWorld;

  /// Map of 33 sovereign Latin American and Caribbean countries plus GF.
  static MapDefinition get latinAmerica => generatedLatinAmerica;

  /// Map of 13 South American regions, including French Guiana.
  static MapDefinition get southAmerica => generatedSouthAmerica;

  /// Map of the 27 Brazilian federative units.
  static MapDefinition get brazilStates => generatedBrazilStates;

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

  /// Preloads one focus map without synchronously decoding it.
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
