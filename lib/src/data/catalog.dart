import 'dart:ui';
import 'models.dart';
import 'generated/south_america_countries.g.dart';
import 'generated/brazil_states.g.dart';

/// Built-in map definitions.
class ShapeMaps {
  ShapeMaps._();

  /// Map of the 13 South American countries in the reference layout.
  static final MapDefinition southAmericaCountries =
      generatedSouthAmericaCountries;

  /// Map of the 27 Brazilian federative units in the reference layout.
  static final MapDefinition brazilStates = generatedBrazilStates;
}

/// Creates a region with a marker anchor.
MapRegion generatedRegion(
  String id,
  String name,
  MapGeometry geometry,
  double x,
  double y,
) => MapRegion(
  id: id,
  name: name,
  geometry: geometry,
  markerAnchor: Offset(x, y),
);
