import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../animation/entrance.dart';
import '../data/models.dart';
import '../state/controller.dart';
import '../style/style.dart';
import 'transform.dart';

/// Paints region fills with animated color interpolation and map entry effects.
class RegionFillPainter extends CustomPainter {
  /// Creates a fill painter.
  RegionFillPainter({
    required this.definition,
    required this.cache,
    required this.data,
    required this.previousData,
    required this.style,
    required this.animation,
    required this.progress,
    required this.entrance,
    required this.repaint,
  }) : _cacheVersion = cache.version,
       super(repaint: repaint);

  final MapDefinition definition;
  final MapRenderCache cache;
  final int _cacheVersion;
  final Map<String, MapRegionData> data;
  final Map<String, MapRegionData> previousData;
  final ShapeMapStyle style;
  final Animation<double> animation;
  final Animation<double> progress;
  final ShapeMapEntrance? entrance;
  final Listenable repaint;
  final Paint _fillPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final p = progress.value;
    if (p >= 1 || entrance == null) {
      _paintAll(canvas, t);
      return;
    }
    final regionProgress = _clamp01(p / _regionPhaseEnd);
    for (var i = 0; i < definition.regions.length; i++) {
      final region = definition.regions[i];
      final color = Color.lerp(
        _colorFor(region.id, previousData),
        _colorFor(region.id, data),
        t,
      )!;
      var alpha = regionProgress;
      var scale = 1.0;
      if (entrance!.style == ShapeMapEntranceStyle.stagger) {
        final local = _clamp01(
          (regionProgress - cache.staggerStart(i)) / _staggerWidth,
        );
        final eased = Curves.easeOut.transform(local);
        alpha = eased;
        scale = eased;
      } else if (entrance!.style == ShapeMapEntranceStyle.grow) {
        scale = 0.01 + 0.99 * regionProgress;
      } else if (entrance!.style == ShapeMapEntranceStyle.draw) {
        alpha = _clamp01((regionProgress - 0.55) / 0.45);
      }
      _fillPaint
        ..style = PaintingStyle.fill
        ..color = _withOpacity(color, alpha);
      _drawTransformed(canvas, cache.paths[i], i, scale);
    }
  }

  void _paintAll(Canvas canvas, double t) {
    for (var i = 0; i < definition.regions.length; i++) {
      final region = definition.regions[i];
      final current = _colorFor(region.id, data);
      final previous = _colorFor(region.id, previousData);
      _fillPaint
        ..style = PaintingStyle.fill
        ..color = Color.lerp(previous, current, t) ?? current;
      canvas.drawPath(cache.paths[i], _fillPaint);
    }
  }

  void _drawTransformed(Canvas canvas, Path path, int index, double scale) {
    if (scale == 1) {
      canvas.drawPath(path, _fillPaint);
      return;
    }
    final center = cache.centers[index];
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, _fillPaint);
    canvas.restore();
  }

  Color _colorFor(String id, Map<String, MapRegionData> source) {
    final item = source[id];
    return item?.fill ?? (item == null ? style.emptyColor : style.dataColor);
  }

  @override
  bool shouldRepaint(covariant RegionFillPainter oldDelegate) =>
      !identical(oldDelegate.definition, definition) ||
      !identical(oldDelegate.cache, cache) ||
      oldDelegate._cacheVersion != _cacheVersion ||
      !identical(oldDelegate.data, data) ||
      !identical(oldDelegate.previousData, previousData) ||
      oldDelegate.style != style ||
      !identical(oldDelegate.animation, animation) ||
      !identical(oldDelegate.progress, progress) ||
      !identical(oldDelegate.repaint, repaint) ||
      oldDelegate.entrance != entrance;
}

/// Paints region borders, using a cached picture after entrance completion.
class RegionBorderPainter extends CustomPainter {
  /// Creates a border painter.
  RegionBorderPainter({
    required this.cache,
    required this.definition,
    required this.style,
    required this.progress,
    required this.entrance,
  }) : _cacheVersion = cache.version,
       super(repaint: progress);

  final MapRenderCache cache;
  final MapDefinition definition;
  final int _cacheVersion;
  final ShapeMapStyle style;
  final Animation<double> progress;
  final ShapeMapEntrance? entrance;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Paint _tracePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    if (p >= 1 || entrance == null) {
      canvas.drawPicture(cache.borderPicture);
      return;
    }
    final regionProgress = _clamp01(p / _regionPhaseEnd);
    _borderPaint
      ..color = style.borderColor
      ..strokeWidth = style.borderWidth * cache.transform.scale;
    for (var i = 0; i < definition.regions.length; i++) {
      var alpha = regionProgress;
      var scale = 1.0;
      if (entrance!.style == ShapeMapEntranceStyle.stagger) {
        final local = _clamp01(
          (regionProgress - cache.staggerStart(i)) / _staggerWidth,
        );
        final eased = Curves.easeOut.transform(local);
        alpha = eased;
        scale = eased;
      } else if (entrance!.style == ShapeMapEntranceStyle.grow) {
        scale = 0.01 + 0.99 * regionProgress;
      }
      if (entrance!.style == ShapeMapEntranceStyle.draw) {
        // Trace: 0..0.65 of the region phase. Fill/border fade in at
        // 0.55..1.0 (same window as RegionFillPainter), and the trace fades
        // out over the same window so it hands off to the final border.
        final drawT = _clamp01(regionProgress / 0.65);
        final settle = _clamp01((regionProgress - 0.55) / 0.45);
        if (settle > 0) {
          _borderPaint
            ..color = _withOpacity(style.borderColor, settle)
            ..strokeWidth = style.borderWidth * cache.transform.scale;
          _drawBorder(canvas, i, 1);
        }
        if (settle < 1) {
          _tracePaint
            ..color = _withOpacity(
              entrance!.drawColor ?? style.marker.fillColor,
              1 - settle,
            )
            ..strokeWidth = entrance!.drawWidth * cache.transform.scale;
          _drawPartial(canvas, i, drawT);
        }
      } else {
        _borderPaint.color = _withOpacity(style.borderColor, alpha);
        _drawBorder(canvas, i, scale);
      }
    }
  }

  void _drawBorder(Canvas canvas, int index, double scale) {
    final path = cache.paths[index];
    final center = cache.centers[index];
    canvas.save();
    canvas.clipPath(path);
    if (scale != 1) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale, scale);
      canvas.translate(-center.dx, -center.dy);
    }
    canvas.drawPath(path, _borderPaint);
    canvas.restore();
  }

  void _drawPartial(Canvas canvas, int index, double progress) {
    // Fully drawn contours come from the cache; only the contour currently
    // being traced is extracted this frame.
    final metrics = cache.drawMetrics[index];
    final segments = cache.drawSegments[index];
    var remaining = cache.drawLengths[index] * progress;
    for (var m = 0; m < metrics.length && remaining > 0; m++) {
      final metric = metrics[m];
      if (remaining >= metric.length) {
        canvas.drawPath(segments[m], _tracePaint);
      } else {
        canvas.drawPath(metric.extractPath(0, remaining), _tracePaint);
      }
      remaining -= metric.length;
    }
  }

  @override
  bool shouldRepaint(covariant RegionBorderPainter oldDelegate) =>
      !identical(oldDelegate.cache, cache) ||
      !identical(oldDelegate.definition, definition) ||
      oldDelegate._cacheVersion != _cacheVersion ||
      oldDelegate.style != style ||
      !identical(oldDelegate.progress, progress) ||
      oldDelegate.entrance != entrance;
}

/// Paints the selected or hovered region highlight.
class HighlightPainter extends CustomPainter {
  /// Creates a highlight painter.
  HighlightPainter({
    required this.cache,
    required this.definition,
    required this.controller,
    required this.style,
    required this.repaint,
    required this.animation,
    required this.progress,
  }) : _cacheVersion = cache.version,
       super(repaint: repaint);

  final MapRenderCache cache;
  final int _cacheVersion;
  final MapDefinition definition;
  final ShapeMapControllerLike controller;
  final ShapeMapStyle style;
  final Listenable repaint;
  final Animation<double> animation;
  final Animation<double> progress;
  final Paint _highlightPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value < 1) return;
    final id = controller.selectedRegionId ?? controller.hoveredRegionId;
    if (id == null) return;
    final index = definition.indexOf(id);
    if (index < 0) return;
    final color = controller.selectedRegionId != null
        ? style.selectedColor ?? style.hoverColor
        : style.hoverColor;
    if (color == null) return;
    _highlightPaint
      ..style = PaintingStyle.fill
      ..color = color.withAlpha((70 * animation.value).round());
    canvas.drawPath(cache.paths[index], _highlightPaint);
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) =>
      !identical(oldDelegate.definition, definition) ||
      !identical(oldDelegate.cache, cache) ||
      oldDelegate._cacheVersion != _cacheVersion ||
      oldDelegate.style != style ||
      !identical(oldDelegate.repaint, repaint) ||
      !identical(oldDelegate.animation, animation) ||
      !identical(oldDelegate.progress, progress);
}

const _regionPhaseEnd = 0.78;
const _staggerWidth = 0.35;

double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

Color _withOpacity(Color color, double opacity) =>
    color.withAlpha((color.a * 255 * _clamp01(opacity)).round());
