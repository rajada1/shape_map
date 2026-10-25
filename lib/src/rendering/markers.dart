import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../animation/entrance.dart';
import '../data/models.dart';
import '../style/style.dart';
import 'transform.dart';

/// A pre-resolved marker entry kept outside the paint loop.
class MarkerLayoutEntry {
  /// Creates a resolved marker entry.
  MarkerLayoutEntry({
    required this.regionId,
    required this.regionIndex,
    required this.position,
    required this.targetDiameter,
    required this.previousDiameter,
    required this.textPainter,
    required this.showLabel,
  });

  /// Region id associated with this entry.
  final String regionId;

  /// Region index resolved from the map id.
  final int regionIndex;

  /// Marker position in view-box coordinates.
  final Offset position;

  /// Current target diameter in view-box units.
  final double targetDiameter;

  /// Previous diameter used by the marker animation.
  final double previousDiameter;

  /// Pre-laid-out label painter, when labels are enabled.
  final TextPainter? textPainter;

  /// Whether a label should be painted.
  final bool showLabel;
}

/// Persistent marker layout cache owned by a [ShapeMap] state.
class MarkerLayoutCache {
  List<MarkerLayoutEntry> _entries = const [];
  List<double> _entranceStarts = const [];
  int _version = 0;
  MapDefinition? _definition;
  List<MapMarkerData>? _markers;
  MarkerStyle? _style;

  /// Resolved entries for the current configuration.
  List<MarkerLayoutEntry> get entries => _entries;

  /// Changes whenever entries are replaced.
  int get version => _version;

  /// Updates entries, disposing text painters from the previous configuration.
  void update(
    MapDefinition definition,
    List<MapMarkerData> markers,
    MarkerStyle style,
    Map<String, double> previousDiameters,
  ) {
    if (identical(_definition, definition) &&
        listEquals(_markers, markers) &&
        _style == style) {
      return;
    }
    _disposeEntries();
    _definition = definition;
    _markers = markers;
    _style = style;
    _entries = markers
        .map((marker) {
          final regionIndex = definition.indexOf(marker.regionId);
          if (regionIndex < 0) return null;
          final region = definition.regions[regionIndex];
          final label = marker.label ?? _formatValue(marker.value);
          final textPainter = marker.showLabel && label.isNotEmpty
              ? (TextPainter(
                  text: TextSpan(
                    text: label,
                    style: style.textStyle.copyWith(color: style.textColor),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout())
              : null;
          return MarkerLayoutEntry(
            regionId: marker.regionId,
            regionIndex: regionIndex,
            position: marker.position ?? region.markerAnchor,
            targetDiameter:
                marker.diameter ?? style.scale.diameterFor(marker.value),
            previousDiameter: previousDiameters[marker.regionId] ?? 0,
            textPainter: textPainter,
            showLabel: marker.showLabel && label.isNotEmpty,
          );
        })
        .whereType<MarkerLayoutEntry>()
        .toList(growable: false);
    final count = _entries.length;
    _entranceStarts = count <= 1
        ? (count == 0 ? const [] : const [0.0])
        : [
            for (var index = 0; index < count; index++)
              index * 0.92 / (count - 1),
          ];
    _version++;
  }

  /// Returns the normalized start of a marker's entrance interval.
  double entranceStart(int index) => _entranceStarts[index];

  /// Returns the current interpolated diameter for each marker.
  Map<String, double> currentDiameters(double t) {
    final result = <String, double>{};
    if (_markers == null) return result;
    for (final entry in _entries) {
      result[entry.regionId] =
          entry.previousDiameter +
          (entry.targetDiameter - entry.previousDiameter) * t;
    }
    return result;
  }

  void _disposeEntries() {
    for (final entry in _entries) {
      entry.textPainter?.dispose();
    }
  }

  /// Releases all cached text layout resources.
  void dispose() => _disposeEntries();

  static String _formatValue(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
}

/// Paints marker circles and labels over a map.
class MarkerPainter extends CustomPainter {
  /// Creates a marker painter.
  MarkerPainter({
    required this.cache,
    required this.layoutCache,
    required this.style,
    required this.animation,
    required this.progress,
    required this.entrance,
    required this.repaint,
  }) : _version = layoutCache.version,
       _cacheVersion = cache.version,
       super(repaint: repaint);

  final MapRenderCache cache;
  final MarkerLayoutCache layoutCache;
  final MarkerStyle style;
  final Animation<double> animation;
  final Animation<double> progress;
  final ShapeMapEntrance? entrance;
  final Listenable repaint;
  final int _version;
  final int _cacheVersion;
  final Paint _fillPaint = Paint();
  final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = cache.transform.scale;
    _fillPaint.color = style.fillColor;
    _borderPaint
      ..color = style.borderColor
      ..strokeWidth = style.borderWidth * scale;
    final t = animation.value;
    final p = progress.value;
    for (var index = 0; index < layoutCache.entries.length; index++) {
      final entry = layoutCache.entries[index];
      final center = cache.transform.forward(entry.position);
      final diameter =
          entry.previousDiameter +
          (entry.targetDiameter - entry.previousDiameter) * t;
      final radius = diameter * scale / 2;
      if (radius <= 0) continue;
      var factor = 1.0;
      if (p < 1 && entrance != null) {
        final markerProgress = _clamp01((p - _regionPhaseEnd) / _markerPhase);
        final local = _clamp01(
          (markerProgress - layoutCache.entranceStart(index)) /
              (1 - layoutCache.entranceStart(index)),
        );
        factor = Curves.easeOutBack.transform(local);
        if (factor <= 0) continue;
      }
      if (factor == 1) {
        _paintMarker(canvas, center, radius, entry);
      } else {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(factor, factor);
        canvas.translate(-center.dx, -center.dy);
        _paintMarker(canvas, center, radius, entry);
        canvas.restore();
      }
    }
  }

  void _paintMarker(
    Canvas canvas,
    Offset center,
    double radius,
    MarkerLayoutEntry entry,
  ) {
    canvas.drawCircle(center, radius, _fillPaint);
    canvas.drawCircle(center, radius, _borderPaint);
    final textPainter = entry.textPainter;
    if (!entry.showLabel || textPainter == null) return;
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant MarkerPainter oldDelegate) =>
      !identical(oldDelegate.cache, cache) ||
      !identical(oldDelegate.layoutCache, layoutCache) ||
      oldDelegate._version != _version ||
      oldDelegate._cacheVersion != _cacheVersion ||
      oldDelegate.style != style ||
      !identical(oldDelegate.animation, animation) ||
      !identical(oldDelegate.progress, progress) ||
      oldDelegate.entrance != entrance ||
      !identical(oldDelegate.repaint, repaint);
}

const _regionPhaseEnd = 0.78;
const _markerPhase = 0.22;

double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();
