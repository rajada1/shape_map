// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';
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

Path _buildQuantizedPath(
  Int32List coordinates,
  Uint32List ringOffsets,
  int ringStart,
  int ringCount,
  double scale,
  bool close,
) {
  // Closed rings need 3 points (6 ints); open border polylines only need 2.
  final minimumInts = close ? 6 : 4;
  final result = Path();
  for (var ring = ringStart; ring < ringStart + ringCount; ring++) {
    final start = ringOffsets[ring];
    final end = ringOffsets[ring + 1];
    if (end - start < minimumInts) continue;
    result.moveTo(coordinates[start] * scale, coordinates[start + 1] * scale);
    for (var i = start + 2; i < end; i += 2) {
      result.lineTo(coordinates[i] * scale, coordinates[i + 1] * scale);
    }
    if (close) result.close();
  }
  return result;
}

/// Immutable geometry represented by legacy path commands or quantized rings.
class MapGeometry {
  /// Creates geometry from a list of commands.
  MapGeometry(List<MapPathCommand> commands)
    : commands = List.unmodifiable(commands),
      _coordinates = null,
      _ringOffsets = null,
      _ringStart = 0,
      _ringCount = 0,
      _scale = 1,
      _cachedPath = _buildPath(commands),
      _cachedBounds = null;

  /// Creates geometry from integer rings and a view-box unit scale.
  MapGeometry.fromQuantized({
    required List<List<int>> rings,
    required double scale,
  }) : commands = const [],
       _coordinates = Int32List.fromList(rings.expand((ring) => ring).toList()),
       _ringOffsets = _offsetsFor(rings),
       _ringStart = 0,
       _ringCount = rings.length,
       _scale = scale,
       _cachedPath = null,
       _cachedBounds = null;

  /// Creates geometry as a zero-copy view over codec buffers.
  ///
  /// This constructor is intended for SMAP materialization. [bounds] is read
  /// from the encoded bounding box, avoiding a second vertex traversal.
  MapGeometry.fromQuantizedBuffers({
    required Int32List coordinates,
    required Uint32List ringOffsets,
    required int ringStart,
    required int ringCount,
    required double scale,
    required Rect bounds,
  }) : commands = const [],
       _coordinates = coordinates,
       _ringOffsets = ringOffsets,
       _ringStart = ringStart,
       _ringCount = ringCount,
       _scale = scale,
       _cachedPath = null,
       _cachedBounds = bounds;

  /// The commands that make up legacy geometry.
  ///
  /// Quantized geometry exposes an empty list to avoid eagerly reconstructing
  /// command objects. Use [path] for drawing.
  final List<MapPathCommand> commands;

  final Int32List? _coordinates;
  final Uint32List? _ringOffsets;
  final int _ringStart;
  final int _ringCount;
  final double _scale;
  Path? _cachedPath;
  Rect? _cachedBounds;

  /// Whether the Flutter path has already been materialized.
  bool get isMaterialized => _cachedPath != null;

  /// The memoized Flutter path for this geometry.
  Path get path => _cachedPath ??= _buildQuantizedPath(
    _coordinates!,
    _ringOffsets!,
    _ringStart,
    _ringCount,
    _scale,
    true,
  );

  /// The axis-aligned bounds of this geometry.
  Rect get bounds => _cachedBounds ??= path.getBounds();

  /// Whether this geometry was loaded from quantized rings.
  bool get isQuantized => _coordinates != null;

  /// Integer rings used by the binary codec, when available.
  List<Int32List> get quantizedRings {
    final coordinates = _coordinates;
    final offsets = _ringOffsets;
    if (coordinates == null || offsets == null) return const [];
    return [
      for (var ring = _ringStart; ring < _ringStart + _ringCount; ring++)
        Int32List.sublistView(coordinates, offsets[ring], offsets[ring + 1]),
    ];
  }
}

Uint32List _offsetsFor(List<List<int>> rings) {
  final offsets = Uint32List(rings.length + 1);
  var offset = 0;
  for (var i = 0; i < rings.length; i++) {
    offsets[i] = offset;
    offset += rings[i].length;
  }
  offsets[rings.length] = offset;
  return offsets;
}

/// A lazily materialized polyline used for shared map borders.
class MapPolyline {
  /// Creates a polyline from quantized coordinates.
  MapPolyline.fromQuantized({
    required List<List<int>> lines,
    required double scale,
  }) : _coordinates = Int32List.fromList(lines.expand((line) => line).toList()),
       _lineOffsets = _offsetsFor(lines),
       _lineStart = 0,
       _lineCount = lines.length,
       _scale = scale,
       _cachedPath = null,
       _cachedBounds = null;

  /// Creates a polyline as a zero-copy view over codec buffers.
  MapPolyline.fromQuantizedBuffers({
    required Int32List coordinates,
    required Uint32List lineOffsets,
    required int lineStart,
    required int lineCount,
    required double scale,
  }) : _coordinates = coordinates,
       _lineOffsets = lineOffsets,
       _lineStart = lineStart,
       _lineCount = lineCount,
       _scale = scale,
       _cachedPath = null,
       _cachedBounds = null;

  final Int32List _coordinates;
  final Uint32List _lineOffsets;
  final int _lineStart;
  final int _lineCount;
  final double _scale;
  Path? _cachedPath;
  Rect? _cachedBounds;

  /// Whether the Flutter path has already been materialized.
  bool get isMaterialized => _cachedPath != null;

  /// The lazily-created open path.
  Path get path => _cachedPath ??= _buildQuantizedPath(
    _coordinates,
    _lineOffsets,
    _lineStart,
    _lineCount,
    _scale,
    false,
  );

  /// Bounds of all polylines.
  Rect get bounds => _cachedBounds ??= path.getBounds();

  /// Integer line coordinates.
  List<Int32List> get quantizedLines => [
    for (var line = _lineStart; line < _lineStart + _lineCount; line++)
      Int32List.sublistView(
        _coordinates,
        _lineOffsets[line],
        _lineOffsets[line + 1],
      ),
  ];
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
    List<MapPolyline> innerBorders = const [],
    List<MapPolyline> outline = const [],
  }) : regions = List.unmodifiable(regions),
       innerBorders = List.unmodifiable(innerBorders),
       outline = List.unmodifiable(outline);

  /// Stable map identifier.
  final String id;

  /// The logical width and height of the map.
  final Size viewBox;

  /// The regions in paint order.
  final List<MapRegion> regions;

  /// Shared internal borders, emitted once per map.
  final List<MapPolyline> innerBorders;

  /// The external outline of the union of all regions.
  final List<MapPolyline> outline;

  /// Whether this definition contains shared border streams.
  bool get hasSharedBorders => innerBorders.isNotEmpty || outline.isNotEmpty;

  Map<String, int>? _regionIndices;
  _MapSpatialGrid? _spatialGrid;

  /// Finds the region with [id], or null when it is not part of this map.
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

  /// Materializes geometry and the hit-test index in cooperative chunks.
  ///
  /// Call this before displaying a large map when its first frame should avoid
  /// lazy path construction. [chunkSize] controls how often the event loop is
  /// given an opportunity to process other work.
  Future<void> warmUp({int chunkSize = 256}) async {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be positive.');
    }
    final paths = <MapGeometry>[for (final region in regions) region.geometry];
    for (var start = 0; start < paths.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, paths.length);
      for (var i = start; i < end; i++) {
        paths[i].path;
      }
      await Future<void>.delayed(Duration.zero);
    }
    final borders = <MapPolyline>[...innerBorders, ...outline];
    for (var start = 0; start < borders.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, borders.length);
      for (var i = start; i < end; i++) {
        borders[i].path;
      }
      await Future<void>.delayed(Duration.zero);
    }
    _spatialGrid ??= _MapSpatialGrid(this);
  }

  /// Finds the topmost region containing [point] in view-box coordinates.
  ///
  /// A uniform 64-by-64 grid reduces hit-test candidates before the exact
  /// lazy path test. The index is built once and memoized per map definition.
  MapRegion? hitTest(Offset point) =>
      (_spatialGrid ??= _MapSpatialGrid(this)).hitTest(point);
}

class _MapSpatialGrid {
  _MapSpatialGrid(this.definition) : _cells = _build(definition);

  static const _size = 64;
  final MapDefinition definition;
  final List<List<int>> _cells;

  static List<List<int>> _build(MapDefinition definition) {
    final cells = List<List<int>>.generate(_size * _size, (_) => <int>[]);
    final width = definition.viewBox.width;
    final height = definition.viewBox.height;
    for (var index = 0; index < definition.regions.length; index++) {
      final bounds = definition.regions[index].bounds;
      final left = (bounds.left / width * _size).floor().clamp(0, _size - 1);
      final right = (bounds.right / width * _size).floor().clamp(0, _size - 1);
      final top = (bounds.top / height * _size).floor().clamp(0, _size - 1);
      final bottom = (bounds.bottom / height * _size).floor().clamp(
        0,
        _size - 1,
      );
      for (var y = top; y <= bottom; y++) {
        for (var x = left; x <= right; x++) {
          cells[y * _size + x].add(index);
        }
      }
    }
    return cells;
  }

  MapRegion? hitTest(Offset point) {
    if (!(Offset.zero & definition.viewBox).contains(point)) return null;
    final x = (point.dx / definition.viewBox.width * _size).floor().clamp(
      0,
      _size - 1,
    );
    final y = (point.dy / definition.viewBox.height * _size).floor().clamp(
      0,
      _size - 1,
    );
    final candidates = _cells[y * _size + x];
    for (var i = candidates.length - 1; i >= 0; i--) {
      final region = definition.regions[candidates[i]];
      if (region.bounds.contains(point) &&
          region.geometry.path.contains(point)) {
        return region;
      }
    }
    return null;
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

  /// Numeric value represented by this marker.
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
