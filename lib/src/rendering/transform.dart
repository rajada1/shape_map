import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../animation/entrance.dart';
import '../data/models.dart';

/// The affine map between view-box and widget coordinates.
class MapTransform {
  /// Creates a transform.
  const MapTransform(this.scale, this.offset);

  /// Uniform scale factor.
  final double scale;

  /// Destination offset.
  final Offset offset;

  /// Converts view-box coordinates to widget coordinates.
  Offset forward(Offset point) => offset + point * scale;

  /// Converts widget coordinates to view-box coordinates.
  Offset inverse(Offset point) => (point - offset) / scale;
}

/// Computes a contain/cover transform using Flutter's fit semantics.
MapTransform calculateTransform(
  MapDefinition definition,
  Size size,
  BoxFit fit,
  Alignment alignment,
) {
  final fitted = applyBoxFit(fit, definition.viewBox, size);
  final destination = alignment.inscribe(
    fitted.destination,
    Offset.zero & size,
  );
  return MapTransform(
    destination.width / definition.viewBox.width,
    destination.topLeft,
  );
}

/// A recorded map layer and the view-box bounds used to cull it.
class MapPictureTile {
  /// Creates a recorded tile.
  MapPictureTile(this.index, this.cullBounds, this.picture);

  /// Zero-based tile index in row-major grid order.
  final int index;

  /// View-box bounds used for visibility culling.
  final Rect cullBounds;

  /// Recorded tile picture in view-box coordinates.
  final ui.Picture picture;
}

const _largeMapRegionThreshold = 1000;
// 8x8 keeps each tile's cull bounds compact while limiting each layer to at
// most 64 drawPicture calls at the default zoom. It is also large enough to
// make a 5,570-region map substantially cheaper at high zoom.
const _largeMapTileGridSize = 8;

/// A memoized set of transformed paths and border pictures for one layout.
class MapRenderCache {
  MapDefinition? _definition;
  Size? _size;
  BoxFit? _fit;
  Alignment? _alignment;
  MapTransform? _transform;
  Float64List? _matrix;
  List<Path> _paths = const [];
  List<Offset> _centers = const [];
  bool _usesCanvasTransform = false;
  List<MapPictureTile> _borderTiles = const [];
  ui.Picture? _fullBorderPicture;
  List<MapPictureTile> _fillTiles = const [];
  List<MapPictureTile> _previousFillTiles = const [];
  // Previous fill pictures indexed by tile index, so paint() looks them up in
  // O(1) instead of scanning the previous tile list.
  List<ui.Picture?> _previousFillByIndex = const [];
  ui.Picture? _fullFillPicture;
  ui.Picture? _previousFullFillPicture;
  List<List<ui.PathMetric>>? _drawMetrics;
  List<List<Path>>? _drawSegments;
  List<double>? _drawLengths;
  List<double> _staggerStarts = const [];
  List<Path> _staggerGroupPaths = const [];
  List<double> _staggerGroupStarts = const [];
  List<int> _staggerGroupRepresentatives = const [];
  List<List<int>> _staggerGroupMembers = const [];
  List<Path> _staggerFillGroupPaths = const [];
  List<Color> _staggerFillGroupColors = const [];
  List<int> _staggerFillGroupRegionCounts = const [];
  List<List<int>> _staggerFillGroupRegionIndices = const [];
  List<double> _staggerFillGroupStarts = const [];
  ShapeMapStaggerOrder? _staggerOrder;
  Path? _largeBorderPath;
  Map<Color, Path>? _fillBatches;
  Map<Color, Path>? _previousFillBatches;
  Map<String, MapRegionData>? _fillBatchData;
  Color? _fillBatchEmptyColor;
  Color? _fillBatchDataColor;
  MapDefinition? _fillBatchDefinition;
  int _fillBatchBuildCount = 0;
  Color? _borderColor;
  double? _borderWidth;
  double? _borderCameraBucket;
  int _borderRecordCount = 0;
  int _version = 0;

  /// Incremented whenever paths, transform or border picture change.
  ///
  /// Painters capture this value so `shouldRepaint` detects mutations of this
  /// (shared, mutable) cache instance.
  int get version => _version;

  /// Updates the cache when layout inputs change.
  void update(
    MapDefinition definition,
    Size size,
    BoxFit fit,
    Alignment alignment,
  ) {
    if (identical(_definition, definition) &&
        _size == size &&
        _fit == fit &&
        _alignment == alignment) {
      return;
    }
    final definitionChanged = !identical(_definition, definition);
    final wasCanvasTransform = _usesCanvasTransform;
    _definition = definition;
    _size = size;
    _fit = fit;
    _alignment = alignment;
    _transform = calculateTransform(definition, size, fit, alignment);
    final transform = _transform!;
    _usesCanvasTransform = definition.regions.length > _largeMapRegionThreshold;
    // Small-map paths are transformed into screen coordinates, so every
    // layout change invalidates the recorded border picture. Large maps keep
    // their view-box picture and apply the new transform on the canvas.
    final borderGeometryChanged =
        definitionChanged ||
        wasCanvasTransform != _usesCanvasTransform ||
        !_usesCanvasTransform;
    final matrix = Float64List.fromList(<double>[
      transform.scale,
      0,
      0,
      0,
      0,
      transform.scale,
      0,
      0,
      0,
      0,
      1,
      0,
      transform.offset.dx,
      transform.offset.dy,
      0,
      1,
    ]);
    _matrix = matrix;
    _paths = definition.regions
        .map(
          (region) => _usesCanvasTransform
              ? region.geometry.path
              : region.geometry.path.transform(matrix),
        )
        .toList(growable: false);
    _centers = definition.regions
        .map(
          (region) => _usesCanvasTransform
              ? region.bounds.center
              : transform.forward(region.bounds.center),
        )
        .toList(growable: false);
    _staggerStarts = const [];
    _staggerGroupPaths = const [];
    _staggerGroupStarts = const [];
    _staggerGroupRepresentatives = const [];
    _staggerGroupMembers = const [];
    _staggerFillGroupPaths = const [];
    _staggerFillGroupColors = const [];
    _staggerFillGroupRegionCounts = const [];
    _staggerFillGroupRegionIndices = const [];
    _staggerFillGroupStarts = const [];
    _staggerOrder = null;
    _drawMetrics = null;
    _drawSegments = null;
    _drawLengths = null;
    if (_usesCanvasTransform &&
        (definitionChanged ||
            wasCanvasTransform != _usesCanvasTransform ||
            _largeBorderPath == null)) {
      _largeBorderPath = _buildLargeBorderPath();
    } else if (!_usesCanvasTransform) {
      _largeBorderPath = null;
    }
    if (borderGeometryChanged) {
      _disposeBorderPicture();
    }
    if (definitionChanged) {
      _fillBatches = null;
      _previousFillBatches = null;
      _fillBatchData = null;
      _fillBatchDefinition = null;
      _disposePictureTiles(_fillTiles);
      _disposePictureTiles(_previousFillTiles);
      _fullFillPicture?.dispose();
      _previousFullFillPicture?.dispose();
      _fillTiles = const [];
      _previousFillTiles = const [];
      _previousFillByIndex = const [];
      _fullFillPicture = null;
      _previousFullFillPicture = null;
    }
    _version++;
  }

  Path _buildLargeBorderPath() {
    final result = Path();
    final definition = _definition!;
    if (definition.hasSharedBorders) {
      for (final border in definition.innerBorders) {
        result.addPath(border.path, Offset.zero);
      }
      for (final border in definition.outline) {
        result.addPath(border.path, Offset.zero);
      }
    } else {
      for (final path in _paths) {
        result.addPath(path, Offset.zero);
      }
    }
    return result;
  }

  /// Updates persistent fill batches for a large map.
  ///
  /// The current batches are retained as the previous snapshot whenever the
  /// target data changes, allowing a cheap crossfade without rebuilding paths
  /// in the paint callback.
  void updateFillBatches(
    Map<String, MapRegionData> data,
    Color emptyColor,
    Color dataColor,
  ) {
    if (!_usesCanvasTransform) return;
    final sameTarget =
        identical(_fillBatchDefinition, _definition) &&
        _fillBatchEmptyColor == emptyColor &&
        _fillBatchDataColor == dataColor &&
        _mapsEqual(_fillBatchData, data);
    if (sameTarget) return;
    _disposePictureTiles(_previousFillTiles);
    _previousFillTiles = _fillTiles;
    _previousFillByIndex = List<ui.Picture?>.filled(_tileCount, null);
    for (final tile in _previousFillTiles) {
      _previousFillByIndex[tile.index] = tile.picture;
    }
    _previousFullFillPicture?.dispose();
    _previousFullFillPicture = _fullFillPicture;
    _fillBatches = _buildFillBatches(data, emptyColor, dataColor);
    _fillTiles = _buildFillTiles(data, emptyColor, dataColor);
    _fullFillPicture = _buildFullFillPicture(_fillBatches!);
    _fillBatchData = data;
    _fillBatchEmptyColor = emptyColor;
    _fillBatchDataColor = dataColor;
    _fillBatchDefinition = _definition;
    if (_staggerOrder != null) _buildStaggerFillGroups();
    _version++;
  }

  ui.Picture _buildFullFillPicture(Map<Color, Path> batches) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final entry in batches.entries) {
      paint.color = entry.key;
      canvas.drawPath(entry.value, paint);
    }
    return recorder.endRecording();
  }

  List<MapPictureTile> _buildFillTiles(
    Map<String, MapRegionData> data,
    Color emptyColor,
    Color dataColor,
  ) {
    final grouped = List<Map<Color, Path>>.generate(
      _tileCount,
      (_) => <Color, Path>{},
    );
    final orderedColors = <Color>[];
    final colorSet = <Color>{};
    final bounds = List<Rect?>.filled(_tileCount, null);
    for (var i = 0; i < _definition!.regions.length; i++) {
      final region = _definition!.regions[i];
      final item = data[region.id];
      final color = item?.fill ?? (item == null ? emptyColor : dataColor);
      if (colorSet.add(color)) orderedColors.add(color);
      final tile = _tileIndexForCenter(region.bounds.center);
      (grouped[tile][color] ??= Path()).addPath(_paths[i], Offset.zero);
      bounds[tile] = _unionRect(bounds[tile], region.bounds);
    }
    final tiles = <MapPictureTile>[];
    for (var index = 0; index < _tileCount; index++) {
      final groups = grouped[index];
      final tileBounds = bounds[index];
      if (tileBounds == null) continue;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..style = PaintingStyle.fill;
      for (final color in orderedColors) {
        final path = groups[color];
        if (path == null) continue;
        paint.color = color;
        canvas.drawPath(path, paint);
      }
      tiles.add(MapPictureTile(index, tileBounds, recorder.endRecording()));
    }
    return tiles;
  }

  Map<Color, Path> _buildFillBatches(
    Map<String, MapRegionData> data,
    Color emptyColor,
    Color dataColor,
  ) {
    _fillBatchBuildCount++;
    final grouped = <Color, Path>{};
    for (var i = 0; i < _definition!.regions.length; i++) {
      final item = data[_definition!.regions[i].id];
      final color = item?.fill ?? (item == null ? emptyColor : dataColor);
      (grouped[color] ??= Path()).addPath(_paths[i], Offset.zero);
    }
    return grouped;
  }

  int get _tileCount => _largeMapTileGridSize * _largeMapTileGridSize;

  int _tileIndexForCenter(Offset center) {
    final viewBox = _definition!.viewBox;
    final column = (center.dx / viewBox.width * _largeMapTileGridSize)
        .floor()
        .clamp(0, _largeMapTileGridSize - 1);
    final row = (center.dy / viewBox.height * _largeMapTileGridSize)
        .floor()
        .clamp(0, _largeMapTileGridSize - 1);
    return row * _largeMapTileGridSize + column;
  }

  static Rect _unionRect(Rect? current, Rect next) {
    if (current == null) return next;
    return Rect.fromLTRB(
      math.min(current.left, next.left),
      math.min(current.top, next.top),
      math.max(current.right, next.right),
      math.max(current.bottom, next.bottom),
    );
  }

  static bool _mapsEqual(
    Map<String, MapRegionData>? first,
    Map<String, MapRegionData> second,
  ) {
    if (first == null || first.length != second.length) return false;
    for (final entry in second.entries) {
      if (first[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// The aggregate large-map border path used during entrance fades.
  Path get largeBorderPath => _largeBorderPath!;

  /// Number of persistent batch constructions, exposed for performance tests.
  @visibleForTesting
  int get fillBatchBuildCount => _fillBatchBuildCount;

  /// Number of fill batches currently cached.
  @visibleForTesting
  int get fillBatchCount => _fillBatches?.length ?? 0;

  /// Current fill batches in the map view-box coordinate space.
  Map<Color, Path> get fillBatches => _fillBatches ?? const {};

  /// Previous fill batches retained while a large-map data transition runs.
  Map<Color, Path> get previousFillBatches => _previousFillBatches ?? const {};

  /// Current fill pictures in view-box coordinate space, one per populated tile.
  List<MapPictureTile> get fillTiles => _fillTiles;

  /// Aggregate current fill snapshot used when the whole map is visible.
  ui.Picture get fullFillPicture => _fullFillPicture!;

  /// Aggregate previous fill snapshot used during a full-map crossfade.
  ui.Picture? get previousFullFillPicture => _previousFullFillPicture;

  /// Previous fill pictures retained while a large-map data transition runs.
  List<MapPictureTile> get previousFillTiles => _previousFillTiles;

  /// Previous fill picture of the tile at [index], if a transition retains it.
  ui.Picture? previousFillPictureAt(int index) =>
      index < _previousFillByIndex.length ? _previousFillByIndex[index] : null;

  /// Number of populated spatial tiles in the current fill snapshot.
  @visibleForTesting
  int get fillTileCount => _fillTiles.length;

  /// Discards the old fill snapshot after a transition completes.
  void completeFillTransition() {
    _disposePictureTiles(_previousFillTiles);
    _previousFillTiles = const [];
    _previousFillByIndex = const [];
    _previousFullFillPicture?.dispose();
    _previousFullFillPicture = null;
  }

  /// Updates cached border pictures when immutable inputs or a scale bucket change.
  void updateBorder(Color color, double width, {double cameraScale = 1}) {
    final bucket = _cameraScaleBucket(cameraScale);
    if (_borderTiles.isNotEmpty &&
        _borderColor == color &&
        _borderWidth == width &&
        _borderCameraBucket == bucket) {
      return;
    }
    _disposeBorderPicture();
    final strokeWidth = _usesCanvasTransform
        ? width / bucket
        : width * transform.scale / bucket;
    if (_usesCanvasTransform) {
      _borderTiles = _buildLargeBorderTiles(color, strokeWidth);
      _fullBorderPicture = _buildFullBorderPicture(color, strokeWidth);
    } else {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round;
      if (_definition!.hasSharedBorders) {
        for (final border in _definition!.innerBorders) {
          canvas.drawPath(border.path.transform(_matrix!), paint);
        }
        final union = Path();
        for (final path in _paths) {
          union.addPath(path, Offset.zero);
        }
        canvas.save();
        canvas.clipPath(union);
        for (final border in _definition!.outline) {
          canvas.drawPath(border.path.transform(_matrix!), paint);
        }
        canvas.restore();
      } else {
        for (final path in _paths) {
          canvas.save();
          canvas.clipPath(path);
          canvas.drawPath(path, paint);
          canvas.restore();
        }
      }
      _borderTiles = [
        MapPictureTile(
          0,
          Offset.zero & (_size ?? Size.zero),
          recorder.endRecording(),
        ),
      ];
    }
    _borderColor = color;
    _borderWidth = width;
    _borderCameraBucket = bucket;
    _borderRecordCount++;
    _version++;
  }

  ui.Picture _buildFullBorderPicture(Color color, double strokeWidth) {
    final recorder = ui.PictureRecorder();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;
    Canvas(recorder).drawPath(_largeBorderPath!, paint);
    return recorder.endRecording();
  }

  List<MapPictureTile> _buildLargeBorderTiles(Color color, double strokeWidth) {
    final grouped = List<Path?>.filled(_tileCount, null);
    final bounds = List<Rect?>.filled(_tileCount, null);
    void add(Path path) {
      final pathBounds = path.getBounds();
      if (pathBounds.isEmpty) return;
      final tile = _tileIndexForCenter(pathBounds.center);
      (grouped[tile] ??= Path()).addPath(path, Offset.zero);
      bounds[tile] = _unionRect(bounds[tile], pathBounds);
    }

    final definition = _definition!;
    if (definition.hasSharedBorders) {
      for (final border in definition.innerBorders) {
        add(border.path);
      }
      for (final border in definition.outline) {
        add(border.path);
      }
    } else {
      for (final path in _paths) {
        add(path);
      }
    }
    final tiles = <MapPictureTile>[];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;
    for (var index = 0; index < _tileCount; index++) {
      final path = grouped[index];
      final pathBounds = bounds[index];
      if (path == null || pathBounds == null) continue;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawPath(path, paint);
      tiles.add(
        MapPictureTile(
          index,
          pathBounds.inflate(strokeWidth),
          recorder.endRecording(),
        ),
      );
    }
    return tiles;
  }

  static double _cameraScaleBucket(double scale) {
    if (scale <= 0 || !scale.isFinite) return 1;
    const subdivisions = 4.0;
    final exponent = math.log(scale) / math.ln2;
    return math
        .pow(2, (exponent * subdivisions).round() / subdivisions)
        .toDouble();
  }

  /// The active transform.
  MapTransform get transform => _transform!;

  /// Whether painting should apply one canvas transform instead of transformed
  /// paths. Large maps use this path to avoid O(regions) resize work.
  bool get usesCanvasTransform => _usesCanvasTransform;

  /// Applies the view-box transform for a large-map paint pass.
  void beginCanvasTransform(Canvas canvas) {
    if (!_usesCanvasTransform) return;
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale, transform.scale);
  }

  /// Transformed region paths in paint order.
  List<Path> get paths => _paths;

  /// Transformed region centers used by grow-style entrances.
  List<Offset> get centers => _centers;

  /// Precomputes the normalized stagger intervals for [order].
  void updateStagger(ShapeMapStaggerOrder order) {
    if (_staggerOrder == order && _staggerStarts.length == _paths.length) {
      return;
    }
    final indices = List<int>.generate(_paths.length, (index) => index);
    indices.sort((a, b) {
      final first = _staggerSortValue(a, order);
      final second = _staggerSortValue(b, order);
      final result = first.compareTo(second);
      return result == 0 ? a.compareTo(b) : result;
    });
    final starts = List<double>.filled(_paths.length, 0);
    final step = indices.length <= 1 ? 0.0 : 0.65 / (indices.length - 1);
    for (var rank = 0; rank < indices.length; rank++) {
      starts[indices[rank]] = rank * step;
    }
    _staggerStarts = starts;
    if (_usesCanvasTransform && indices.isNotEmpty) {
      final groupCount = indices.length.clamp(1, 48);
      final groups = List<Path>.generate(groupCount, (_) => Path());
      final members = List<List<int>>.generate(groupCount, (_) => <int>[]);
      final representatives = List<int>.filled(groupCount, -1);
      for (var rank = 0; rank < indices.length; rank++) {
        final group = rank * groupCount ~/ indices.length;
        final index = indices[rank];
        representatives[group] = representatives[group] < 0
            ? index
            : representatives[group];
        members[group].add(index);
        groups[group].addPath(_paths[index], Offset.zero);
      }
      final groupStep = groupCount <= 1 ? 0.0 : 0.65 / (groupCount - 1);
      _staggerGroupPaths = groups;
      _staggerGroupMembers = members;
      _staggerGroupRepresentatives = representatives;
      _staggerGroupStarts = [
        for (var group = 0; group < groupCount; group++) group * groupStep,
      ];
      _buildStaggerFillGroups();
    } else {
      _staggerGroupPaths = const [];
      _staggerGroupMembers = const [];
      _staggerGroupStarts = const [];
      _staggerGroupRepresentatives = const [];
      _staggerFillGroupPaths = const [];
      _staggerFillGroupColors = const [];
      _staggerFillGroupRegionCounts = const [];
      _staggerFillGroupStarts = const [];
    }
    _staggerOrder = order;
  }

  void _buildStaggerFillGroups() {
    if (!_usesCanvasTransform || _fillBatchData == null) return;
    final paths = <Path>[];
    final colors = <Color>[];
    final counts = <int>[];
    final regionIndices = <List<int>>[];
    final starts = <double>[];
    for (var group = 0; group < _staggerGroupMembers.length; group++) {
      final grouped = <Color, Path>{};
      final groupedCounts = <Color, int>{};
      final groupedIndices = <Color, List<int>>{};
      for (final index in _staggerGroupMembers[group]) {
        final region = _definition!.regions[index];
        final color = _fillColor(region.id);
        (grouped[color] ??= Path()).addPath(_paths[index], Offset.zero);
        groupedCounts[color] = (groupedCounts[color] ?? 0) + 1;
        (groupedIndices[color] ??= <int>[]).add(index);
      }
      for (final entry in grouped.entries) {
        paths.add(entry.value);
        colors.add(entry.key);
        counts.add(groupedCounts[entry.key]!);
        regionIndices.add(groupedIndices[entry.key]!);
        starts.add(_staggerGroupStarts[group]);
      }
    }
    _staggerFillGroupPaths = paths;
    _staggerFillGroupColors = colors;
    _staggerFillGroupRegionCounts = counts;
    _staggerFillGroupRegionIndices = regionIndices;
    _staggerFillGroupStarts = starts;
  }

  Color _fillColor(String id) {
    final item = _fillBatchData![id];
    return item?.fill ??
        (item == null ? _fillBatchEmptyColor! : _fillBatchDataColor!);
  }

  /// Returns the normalized stagger start for the region at [index].
  double staggerStart(int index) => _staggerStarts[index];

  /// Grouped paths used by large-map stagger entrances.
  List<Path> get staggerGroupPaths => _staggerGroupPaths;

  /// Start values corresponding to [staggerGroupPaths].
  List<double> get staggerGroupStarts => _staggerGroupStarts;

  /// Representative region indices corresponding to stagger groups.
  List<int> get staggerGroupRepresentatives => _staggerGroupRepresentatives;

  /// Fill paths grouped by stagger band and then by color.
  List<Path> get staggerFillGroupPaths => _staggerFillGroupPaths;

  /// Colors corresponding to [staggerFillGroupPaths].
  List<Color> get staggerFillGroupColors => _staggerFillGroupColors;

  /// Region counts corresponding to [staggerFillGroupPaths].
  @visibleForTesting
  List<int> get staggerFillGroupRegionCounts => _staggerFillGroupRegionCounts;

  /// Region indices represented by each color-homogeneous fill group.
  @visibleForTesting
  List<List<int>> get staggerFillGroupRegionIndices =>
      _staggerFillGroupRegionIndices;

  /// Start values corresponding to [staggerFillGroupPaths].
  List<double> get staggerFillGroupStarts => _staggerFillGroupStarts;

  /// Returns lazily cached path metrics used by the draw entrance.
  ///
  /// Call [prepareDraw] outside of `paint()` so this never computes there.
  List<List<ui.PathMetric>> get drawMetrics => _drawMetrics ??= [
    for (final path in _paths) path.computeMetrics().toList(growable: false),
  ];

  /// Full extracted contour of every metric, per region, so a draw frame only
  /// needs to extract the single partially-drawn contour.
  List<List<Path>> get drawSegments => _drawSegments ??= [
    for (final metrics in drawMetrics)
      [for (final metric in metrics) metric.extractPath(0, metric.length)],
  ];

  /// Precomputes all draw-entrance geometry. Idempotent until [update]
  /// invalidates the layout.
  void prepareDraw() {
    drawLengths;
    drawSegments;
  }

  /// Returns the total length of each cached region path.
  List<double> get drawLengths => _drawLengths ??= [
    for (final metrics in drawMetrics)
      metrics.fold<double>(0, (total, metric) => total + metric.length),
  ];

  double _staggerSortValue(int index, ShapeMapStaggerOrder order) {
    final center = _centers[index];
    switch (order) {
      case ShapeMapStaggerOrder.mapOrder:
        return index.toDouble();
      case ShapeMapStaggerOrder.topToBottom:
        return center.dy;
      case ShapeMapStaggerOrder.bottomToTop:
        return -center.dy;
      case ShapeMapStaggerOrder.leftToRight:
        return center.dx;
      case ShapeMapStaggerOrder.rightToLeft:
        return -center.dx;
    }
  }

  /// Cached border pictures, one per populated tile for large maps.
  List<MapPictureTile> get borderTiles => _borderTiles;

  /// Compatibility view of the border picture for small-map callers.
  ui.Picture get borderPicture => _borderTiles.first.picture;

  /// Aggregate border snapshot used when the whole large map is visible.
  ui.Picture? get fullBorderPicture => _fullBorderPicture;

  /// Number of border recordings, exposed for performance tests.
  @visibleForTesting
  int get borderRecordCount => _borderRecordCount;

  /// Returns the visible view-box rectangle for the current camera.
  Rect visibleViewBox(
    Size size, {
    double cameraScale = 1,
    Offset pan = Offset.zero,
  }) {
    final first = transform.inverse((Offset.zero - pan) / cameraScale);
    final last = transform.inverse(
      Offset(size.width, size.height) / cameraScale - pan / cameraScale,
    );
    return Rect.fromLTRB(
      math.min(first.dx, last.dx),
      math.min(first.dy, last.dy),
      math.max(first.dx, last.dx),
      math.max(first.dy, last.dy),
    );
  }

  void _disposeBorderPicture() {
    _disposePictureTiles(_borderTiles);
    _borderTiles = const [];
    _fullBorderPicture?.dispose();
    _fullBorderPicture = null;
    _borderColor = null;
    _borderWidth = null;
    _borderCameraBucket = null;
  }

  static void _disposePictureTiles(List<MapPictureTile> tiles) {
    for (final tile in tiles) {
      tile.picture.dispose();
    }
  }

  /// Releases native picture resources owned by this cache.
  void dispose() {
    _disposeBorderPicture();
    _disposePictureTiles(_fillTiles);
    _disposePictureTiles(_previousFillTiles);
    _fullFillPicture?.dispose();
    _previousFullFillPicture?.dispose();
    _fillTiles = const [];
    _previousFillTiles = const [];
    _previousFillByIndex = const [];
  }
}
