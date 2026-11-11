// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;

import '../style/style.dart';

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

  /// View-box units represented by one quantized integer unit.
  double get quantizationScale => _scale;

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

/// Latitudes at the top and bottom edges of a Mercator map's view box.
typedef MercatorLatitudes = ({double north, double south});

/// A complete map and its view-box geometry.
class MapDefinition {
  /// Creates a map definition.
  MapDefinition({
    required this.id,
    required this.viewBox,
    required List<MapRegion> regions,
    List<MapPolyline> innerBorders = const [],
    List<MapPolyline> outline = const [],
    this.focusRegionPrefix,
    this.mercatorLatitudes,
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

  /// Prefix identifying the focused country's admin-1 regions, when present.
  ///
  /// Focus maps use IDs such as `BR-SP` for the selected country and ISO
  /// alpha-2 IDs for the surrounding context. The prefix lets camera code fit
  /// the whole country without requiring a synthetic region.
  final String? focusRegionPrefix;

  /// For Mercator maps, the latitudes at the view box's top and bottom edges.
  ///
  /// Mercator inflates areas towards the poles. When set, area-based
  /// heuristics such as [primaryFocusBounds] weight each piece by the true
  /// ground area so Svalbard does not outweigh mainland Norway.
  final MercatorLatitudes? mercatorLatitudes;

  /// Relative ground-area weight of a point at view-box [y] (1 at the equator).
  double _areaWeightAt(double y) {
    final latitudes = mercatorLatitudes;
    if (latitudes == null || viewBox.height <= 0) return 1;
    double mercator(double degrees) =>
        math.log(math.tan(math.pi / 4 + degrees * math.pi / 360));
    final top = mercator(latitudes.north);
    final bottom = mercator(latitudes.south);
    final value = top + (bottom - top) * (y / viewBox.height).clamp(0.0, 1.0);
    final latitude = 2 * math.atan(math.exp(value)) - math.pi / 2;
    final cosine = math.cos(latitude);
    return cosine * cosine;
  }

  /// Bounds enclosing the geometry of every region in this map.
  ///
  /// The union is calculated on first access and memoized for subsequent
  /// camera fits and layout calculations.
  Rect get contentBounds {
    final cached = _contentBounds;
    if (cached != null) return cached;
    Rect? result;
    for (final region in regions) {
      result = result == null
          ? region.bounds
          : result.expandToInclude(region.bounds);
    }
    return _contentBounds = result ?? Rect.zero;
  }

  /// Bounds enclosing all regions in [focusRegionPrefix].
  Rect? get focusBounds {
    final explicitPrefix = focusRegionPrefix;
    final prefix =
        explicitPrefix ??
        (id.startsWith('southamericafocus')
            ? '${id.substring('southamericafocus'.length).toUpperCase()}-'
            : null);
    if (prefix == null) return null;
    Rect? result;
    for (final region in regions) {
      if (!region.id.startsWith(prefix)) continue;
      result = result == null
          ? region.bounds
          : result.expandToInclude(region.bounds);
    }
    return result;
  }

  /// Bounds of the principal territory in the focused country.
  ///
  /// Focus regions are grouped by touching or nearby bounds. The largest
  /// connected land cluster is selected, with small nearby components included
  /// for compact annexed islands such as Corsica. If no cluster represents at
  /// least 70% of the land-area score, the whole focus is retained. This
  /// threshold tolerates simplified administrative polygons. Indonesia, Japan
  /// and New Zealand explicitly retain their full archipelagos because none has
  /// one unambiguous principal territory.
  Rect? get primaryFocusBounds {
    final cached = _primaryFocusBounds;
    if (cached != null) return cached;
    final prefix = focusRegionPrefix;
    if (prefix == null) return null;
    final focused = regions
        .where((region) => region.id.startsWith(prefix))
        .toList();
    if (focused.isEmpty) return null;

    var pieces = _focusPieces(focused, _areaWeightAt);
    if (pieces.length == 1) {
      return _primaryFocusBounds = pieces.single.bounds;
    }
    // In a shared world frame a country cut at the antimeridian (Fiji, the
    // Aleutians) spans the whole width. Keep the side holding most of the
    // land; a genuinely wide country such as Russia keeps every piece.
    var extent = _unionPieceBounds(pieces);
    if (extent.width > viewBox.width * 0.5) {
      final middle = viewBox.width / 2;
      final left = pieces.where((p) => p.bounds.center.dx < middle).toList();
      final right = pieces.where((p) => p.bounds.center.dx >= middle).toList();
      double score(List<_FocusPiece> side) =>
          side.fold(0, (sum, piece) => sum + piece.score);
      final majority = score(left) >= score(right) ? left : right;
      final majorityExtent = _unionPieceBounds(majority);
      if (majority.isNotEmpty && majorityExtent.width <= viewBox.width * 0.5) {
        pieces = majority;
        extent = majorityExtent;
      }
    }
    // Clustering distances are relative to the country's own footprint, so
    // the heuristics behave the same in a per-country frame and in the world.
    final reference = extent.longestSide;
    final components = _focusComponents(pieces, reference);
    if (components.length == 1) {
      return _primaryFocusBounds = extent;
    }
    final scored = [
      for (final component in components)
        (
          pieces: component,
          score: component.fold<double>(0, (sum, piece) => sum + piece.score),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    final largest = scored.first;
    final countryIso = prefix.length >= 2 ? prefix.substring(0, 2) : '';
    const noPrincipalTerritory = {'ID', 'JP', 'NZ'};
    if (noPrincipalTerritory.contains(countryIso)) {
      return _primaryFocusBounds = extent;
    }
    final totalScore = scored.fold<double>(0, (sum, item) => sum + item.score);
    if (largest.score / totalScore < 0.70) {
      return _primaryFocusBounds = extent;
    }

    var selected = <_FocusPiece>[...largest.pieces];
    var selectedBounds = _unionPieceBounds(selected);
    final proximity = reference * 0.06;
    for (final candidate in scored.skip(1)) {
      final candidateBounds = _unionPieceBounds(candidate.pieces);
      final gap = _rectGap(selectedBounds, candidateBounds);
      if (gap <= proximity && candidate.score <= largest.score * 0.12) {
        selected = [...selected, ...candidate.pieces];
        selectedBounds = _unionPieceBounds(selected);
      }
    }
    return _primaryFocusBounds = selectedBounds;
  }

  /// Whether this definition contains shared border streams.
  bool get hasSharedBorders => innerBorders.isNotEmpty || outline.isNotEmpty;

  /// Returns a map that draws [detail] on top of this map.
  ///
  /// Both maps must share the same [viewBox] (same projection and
  /// normalization), as the generated world map and the country layers from
  /// [ShapeMaps.loadCountryFocus] do. Regions of [detail] come after this
  /// map's regions, so they paint above them and win hit tests. Base regions
  /// listed in [hiddenRegionIds] are dropped; by default every base region is
  /// kept, so the coarse country shape still fills tiny gaps along the coast
  /// of the finer admin-1 geometry.
  ///
  /// The detail's [innerBorders] are kept and its [outline] is dropped: the
  /// base already draws the country outline, and two slightly different
  /// coastlines would otherwise overlap.
  MapDefinition withDetail(
    MapDefinition detail, {
    String? id,
    Set<String> hiddenRegionIds = const {},
  }) {
    if (detail.viewBox != viewBox) {
      throw ArgumentError.value(
        detail,
        'detail',
        'Expected a map with viewBox $viewBox, got ${detail.viewBox}.',
      );
    }
    final detailIds = {for (final region in detail.regions) region.id};
    return MapDefinition(
      id: id ?? '${this.id}+${detail.id}',
      viewBox: viewBox,
      regions: [
        for (final region in regions)
          if (!hiddenRegionIds.contains(region.id) &&
              !detailIds.contains(region.id))
            region,
        ...detail.regions,
      ],
      innerBorders: [...innerBorders, ...detail.innerBorders],
      outline: outline,
      focusRegionPrefix: detail.focusRegionPrefix ?? focusRegionPrefix,
      mercatorLatitudes: mercatorLatitudes ?? detail.mercatorLatitudes,
    );
  }

  Map<String, int>? _regionIndices;
  _MapSpatialGrid? _spatialGrid;
  Rect? _contentBounds;
  Rect? _primaryFocusBounds;

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

class _FocusPiece {
  const _FocusPiece(this.bounds, this.score);

  final Rect bounds;
  final double score;
}

List<_FocusPiece> _focusPieces(
  List<MapRegion> regions,
  double Function(double y) areaWeightAt,
) {
  final pieces = <_FocusPiece>[];
  for (final region in regions) {
    final rings = region.geometry.quantizedRings;
    if (rings.isEmpty) {
      final bounds = region.bounds;
      pieces.add(
        _FocusPiece(
          bounds,
          bounds.width * bounds.height * areaWeightAt(bounds.center.dy),
        ),
      );
      continue;
    }
    for (final ring in rings) {
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      var signedArea = 0.0;
      for (var index = 0; index < ring.length; index += 2) {
        final next = (index + 2) % ring.length;
        final x = ring[index] * region.geometry.quantizationScale;
        final y = ring[index + 1] * region.geometry.quantizationScale;
        final nextX = ring[next] * region.geometry.quantizationScale;
        final nextY = ring[next + 1] * region.geometry.quantizationScale;
        signedArea += x * nextY - nextX * y;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
      final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      final score = signedArea.abs() / 2;
      pieces.add(
        _FocusPiece(
          bounds,
          (score == 0 ? bounds.width * bounds.height : score) *
              areaWeightAt(bounds.center.dy),
        ),
      );
    }
  }
  return pieces;
}

Rect _unionPieceBounds(List<_FocusPiece> pieces) {
  var result = pieces.first.bounds;
  for (final piece in pieces.skip(1)) {
    result = result.expandToInclude(piece.bounds);
  }
  return result;
}

double _rectGap(Rect a, Rect b) {
  final dx = a.right < b.left
      ? b.left - a.right
      : b.right < a.left
      ? a.left - b.right
      : 0;
  final dy = a.bottom < b.top
      ? b.top - a.bottom
      : b.bottom < a.top
      ? a.top - b.bottom
      : 0;
  return math.sqrt(dx * dx + dy * dy);
}

List<List<_FocusPiece>> _focusComponents(
  List<_FocusPiece> pieces,
  double reference,
) {
  final threshold = math.max(reference, 1e-6) * 0.015;
  final buckets = <String, List<int>>{};
  String key(int x, int y) => '$x:$y';
  for (var index = 0; index < pieces.length; index++) {
    final bounds = pieces[index].bounds;
    final left = (bounds.left / threshold).floor();
    final right = (bounds.right / threshold).floor();
    final top = (bounds.top / threshold).floor();
    final bottom = (bounds.bottom / threshold).floor();
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        (buckets[key(x, y)] ??= <int>[]).add(index);
      }
    }
  }

  final remaining = <int>{
    ...List<int>.generate(pieces.length, (index) => index),
  };
  final components = <List<_FocusPiece>>[];
  while (remaining.isNotEmpty) {
    final component = <_FocusPiece>[];
    final queue = <int>[remaining.first];
    remaining.remove(queue.first);
    while (queue.isNotEmpty) {
      final currentIndex = queue.removeLast();
      final current = pieces[currentIndex];
      component.add(current);
      final left = ((current.bounds.left - threshold) / threshold).floor();
      final right = ((current.bounds.right + threshold) / threshold).floor();
      final top = ((current.bounds.top - threshold) / threshold).floor();
      final bottom = ((current.bounds.bottom + threshold) / threshold).floor();
      final candidates = <int>{};
      for (var y = top; y <= bottom; y++) {
        for (var x = left; x <= right; x++) {
          candidates.addAll(buckets[key(x, y)] ?? const <int>[]);
        }
      }
      for (final candidateIndex in candidates) {
        if (!remaining.contains(candidateIndex)) continue;
        if (_rectGap(current.bounds, pieces[candidateIndex].bounds) >
            threshold) {
          continue;
        }
        remaining.remove(candidateIndex);
        queue.add(candidateIndex);
      }
    }
    components.add(component);
  }
  return components;
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
    this.diameterUnit,
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

  /// Optional diameter override. Its unit is [diameterUnit], or the marker
  /// style scale unit when [diameterUnit] is null.
  final double? diameter;

  /// Optional diameter override unit. Null uses the marker style scale unit.
  final MarkerDiameterUnit? diameterUnit;

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
      other.diameterUnit == diameterUnit &&
      other.showLabel == showLabel;

  @override
  int get hashCode => Object.hash(
    regionId,
    value,
    label,
    position,
    diameter,
    diameterUnit,
    showLabel,
  );
}
