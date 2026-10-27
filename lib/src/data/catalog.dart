import 'models.dart';
import 'generated/brazil_states.g.dart';
import 'generated/latin_america.g.dart';
import 'generated/south_america.g.dart';
import 'generated/world.g.dart';

/// Identifies a built-in map that can be preloaded.
enum ShapeMapId { world, latinAmerica, southAmerica, brazilStates }

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
    ]);
  }

  /// Deprecated alias for [southAmerica].
  @Deprecated('Use ShapeMaps.southAmerica')
  static MapDefinition get southAmericaCountries => southAmerica;
}
