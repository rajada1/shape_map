import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// A memoized set of transformed paths and the border picture for one layout.
class MapRenderCache {
  MapDefinition? _definition;
  Size? _size;
  BoxFit? _fit;
  Alignment? _alignment;
  MapTransform? _transform;
  List<Path> _paths = const [];
  List<Offset> _centers = const [];
  ui.Picture? _borderPicture;
  List<List<ui.PathMetric>>? _drawMetrics;
  List<List<Path>>? _drawSegments;
  List<double>? _drawLengths;
  List<double> _staggerStarts = const [];
  ShapeMapStaggerOrder? _staggerOrder;
  Color? _borderColor;
  double? _borderWidth;
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
    _definition = definition;
    _size = size;
    _fit = fit;
    _alignment = alignment;
    _transform = calculateTransform(definition, size, fit, alignment);
    final transform = _transform!;
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
    _paths = definition.regions
        .map((region) => region.geometry.path.transform(matrix))
        .toList(growable: false);
    _centers = definition.regions
        .map((region) => transform.forward(region.bounds.center))
        .toList(growable: false);
    _staggerStarts = const [];
    _staggerOrder = null;
    _drawMetrics = null;
    _drawSegments = null;
    _drawLengths = null;
    _disposeBorderPicture();
    _version++;
  }

  /// Updates the cached border picture when its immutable inputs change.
  void updateBorder(Color color, double width) {
    if (_borderPicture != null &&
        _borderColor == color &&
        _borderWidth == width) {
      return;
    }
    _disposeBorderPicture();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * transform.scale
      ..strokeJoin = StrokeJoin.round;
    for (final path in _paths) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    _borderPicture = recorder.endRecording();
    _borderColor = color;
    _borderWidth = width;
    _version++;
  }

  /// The active transform.
  MapTransform get transform => _transform!;

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
    _staggerOrder = order;
  }

  /// Returns the normalized stagger start for the region at [index].
  double staggerStart(int index) => _staggerStarts[index];

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

  /// The cached border picture, after [updateBorder] has been called.
  ui.Picture get borderPicture => _borderPicture!;

  void _disposeBorderPicture() {
    _borderPicture?.dispose();
    _borderPicture = null;
    _borderColor = null;
    _borderWidth = null;
  }

  /// Releases native picture resources owned by this cache.
  void dispose() => _disposeBorderPicture();
}
