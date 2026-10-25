import 'dart:ui';

/// A single SVG-like command used to describe map geometry.
class MapPathCommand {
  /// Creates a move command.
  const MapPathCommand.move(this.x, this.y) : type = MapPathCommandType.move;

  /// Creates a line command.
  const MapPathCommand.line(this.x, this.y) : type = MapPathCommandType.line;

  /// Creates a horizontal line command.
  const MapPathCommand.horizontal(this.x)
    : type = MapPathCommandType.horizontal,
      y = 0;

  /// Creates a vertical line command.
  const MapPathCommand.vertical(this.y)
    : type = MapPathCommandType.vertical,
      x = 0;

  /// Creates a close-path command.
  const MapPathCommand.close() : type = MapPathCommandType.close, x = 0, y = 0;

  /// The command kind.
  final MapPathCommandType type;

  /// The x coordinate, when applicable.
  final double x;

  /// The y coordinate, when applicable.
  final double y;
}

/// The supported map path command kinds.
enum MapPathCommandType { move, line, horizontal, vertical, close }

Path _buildPath(List<MapPathCommand> commands) {
  final result = Path();
  var current = Offset.zero;
  for (final command in commands) {
    switch (command.type) {
      case MapPathCommandType.move:
        current = Offset(command.x, command.y);
        result.moveTo(current.dx, current.dy);
      case MapPathCommandType.line:
        current = Offset(command.x, command.y);
        result.lineTo(current.dx, current.dy);
      case MapPathCommandType.horizontal:
        current = Offset(command.x, current.dy);
        result.lineTo(current.dx, current.dy);
      case MapPathCommandType.vertical:
        current = Offset(current.dx, command.y);
        result.lineTo(current.dx, current.dy);
      case MapPathCommandType.close:
        result.close();
    }
  }
  return result;
}

/// Immutable geometry represented by path commands.
class MapGeometry {
  /// Creates geometry from a list of commands.
  MapGeometry(List<MapPathCommand> commands)
    : commands = List.unmodifiable(commands),
      _cachedPath = _buildPath(commands);

  /// The commands that make up this geometry.
  final List<MapPathCommand> commands;

  final Path _cachedPath;
  Rect? _cachedBounds;

  /// The memoized Flutter path for this geometry.
  Path get path => _cachedPath;

  /// The axis-aligned bounds of this geometry.
  Rect get bounds => _cachedBounds ??= path.getBounds();
}

/// A named geographic region in a map definition.
class MapRegion {
  /// Creates a map region.
  const MapRegion({
    required this.id,
    required this.name,
    required this.geometry,
    required this.markerAnchor,
  });

  /// Stable region identifier.
  final String id;

  /// Human-readable region name.
  final String name;

  /// Region geometry in the definition view box.
  final MapGeometry geometry;

  /// Default marker position in view-box coordinates.
  final Offset markerAnchor;

  /// The bounds of this region.
  Rect get bounds => geometry.bounds;

  /// A bounds-based center useful for labels and fallback layouts.
  Offset get centroid => bounds.center;
}

/// A complete map and its view-box geometry.
class MapDefinition {
  /// Creates a map definition.
  MapDefinition({
    required this.id,
    required this.viewBox,
    required List<MapRegion> regions,
  }) : regions = List.unmodifiable(regions);

  /// Stable map identifier.
  final String id;

  /// The logical width and height of the map.
  final Size viewBox;

  /// The regions in paint order.
  final List<MapRegion> regions;

  Map<String, int>? _regionIndices;

  /// Returns the region with [id], or null when it is not part of this map.
  MapRegion? regionById(String id) {
    final index = indexOf(id);
    return index < 0 ? null : regions[index];
  }

  /// Returns the paint-order index for [id], or -1 when it is absent.
  int indexOf(String id) {
    final indices = _regionIndices ??= {
      for (var i = 0; i < regions.length; i++) regions[i].id: i,
    };
    return indices[id] ?? -1;
  }
}

/// Data used to color and label one region.
class MapRegionData {
  /// Creates region data.
  const MapRegionData({this.fill, this.value, this.label});

  /// Optional fill color. Null uses the style's data color.
  final Color? fill;

  /// Optional numeric value shown in a tooltip or marker.
  final num? value;

  /// Optional display label.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is MapRegionData &&
      other.fill == fill &&
      other.value == value &&
      other.label == label;

  @override
  int get hashCode => Object.hash(fill, value, label);
}

/// A marker displayed on top of a map region.
class MapMarkerData {
  /// Creates marker data.
  const MapMarkerData({
    required this.regionId,
    required this.value,
    this.label,
    this.position,
    this.diameter,
    this.showLabel = true,
  });

  /// Region associated with this marker.
  final String regionId;

  /// Numeric value represented by the marker.
  final num value;

  /// Optional marker text override.
  final String? label;

  /// Optional position override in view-box coordinates.
  final Offset? position;

  /// Optional diameter override in view-box units.
  final double? diameter;

  /// Whether marker text should be painted. Set false for a text-free badge.
  final bool showLabel;

  @override
  bool operator ==(Object other) =>
      other is MapMarkerData &&
      other.regionId == regionId &&
      other.value == value &&
      other.label == label &&
      other.position == position &&
      other.diameter == diameter &&
      other.showLabel == showLabel;

  @override
  int get hashCode =>
      Object.hash(regionId, value, label, position, diameter, showLabel);
}
