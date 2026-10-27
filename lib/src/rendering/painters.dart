import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../animation/entrance.dart';
import '../data/models.dart';
import '../state/camera.dart';
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
    this.camera,
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
  final ShapeMapCameraController? camera;
  final Paint _fillPaint = Paint();
  final Paint _layerPaint = Paint();
  int _drawCalls = 0;
  int _tilesDrawn = 0;

  /// Number of canvas draw calls made by the last paint pass.
  @visibleForTesting
  int get drawCalls => _drawCalls;

  /// Number of populated spatial tiles visited by the last paint pass.
  @visibleForTesting
  int get tilesDrawn => _tilesDrawn;

  /// Backwards-compatible alias for the large-map draw-call counter.
  @visibleForTesting
  int get fillBatchDrawCount => _drawCalls;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCalls = 0;
    _tilesDrawn = 0;
    final hasCamera = camera != null;
    if (hasCamera) {
      canvas.save();
      canvas.translate(camera!.pan.dx, camera!.pan.dy);
      canvas.scale(camera!.scale, camera!.scale);
    }
    final transformed = cache.usesCanvasTransform;
    final visibleViewBox = transformed
        ? cache.visibleViewBox(
            size,
            cameraScale: camera?.scale ?? 1,
            pan: camera?.pan ?? Offset.zero,
          )
        : null;
    if (transformed) canvas.save();
    cache.beginCanvasTransform(canvas);
    final t = animation.value;
    final p = progress.value;
    if (transformed) {
      if (p >= 1 || entrance == null) {
        _paintAll(canvas, t, visibleViewBox: visibleViewBox);
        canvas.restore();
        if (hasCamera) canvas.restore();
        return;
      }
      final regionProgress = _clamp01(p / _regionPhaseEnd);
      final entranceStyle = entrance!.style == ShapeMapEntranceStyle.stagger
          ? ShapeMapEntranceStyle.stagger
          : ShapeMapEntranceStyle.fade;
      if (entranceStyle == ShapeMapEntranceStyle.stagger) {
        final groups = cache.staggerFillGroupPaths;
        final starts = cache.staggerFillGroupStarts;
        final colors = cache.staggerFillGroupColors;
        for (var group = 0; group < groups.length; group++) {
          final local = _clamp01(
            (regionProgress - starts[group]) / _staggerWidth,
          );
          final alpha = Curves.easeOut.transform(local);
          _fillPaint
            ..style = PaintingStyle.fill
            ..color = _withOpacity(colors[group], alpha);
          canvas.drawPath(groups[group], _fillPaint);
          _drawCalls++;
        }
      } else {
        _paintAll(
          canvas,
          t,
          alpha: regionProgress,
          visibleViewBox: visibleViewBox,
        );
      }
      canvas.restore();
      if (hasCamera) canvas.restore();
      return;
    }
    if (p >= 1 || entrance == null) {
      _paintAll(canvas, t);
      if (hasCamera) canvas.restore();
      return;
    }
    final regionProgress = _clamp01(p / _regionPhaseEnd);
    final entranceStyle = entrance!.style;
    for (var i = 0; i < definition.regions.length; i++) {
      final region = definition.regions[i];
      final color = Color.lerp(
        _colorFor(region.id, previousData),
        _colorFor(region.id, data),
        t,
      )!;
      var alpha = regionProgress;
      var scale = 1.0;
      if (entranceStyle == ShapeMapEntranceStyle.stagger) {
        final local = _clamp01(
          (regionProgress - cache.staggerStart(i)) / _staggerWidth,
        );
        final eased = Curves.easeOut.transform(local);
        alpha = eased;
        scale = eased;
      } else if (entranceStyle == ShapeMapEntranceStyle.grow) {
        scale = 0.01 + 0.99 * regionProgress;
      } else if (entranceStyle == ShapeMapEntranceStyle.draw) {
        alpha = _clamp01((regionProgress - 0.55) / 0.45);
      }
      _fillPaint
        ..style = PaintingStyle.fill
        ..color = _withOpacity(color, alpha);
      _drawTransformed(canvas, cache.paths[i], i, scale);
    }
    if (hasCamera) canvas.restore();
  }

  void _paintAll(
    Canvas canvas,
    double t, {
    double alpha = 1,
    Rect? visibleViewBox,
  }) {
    if (cache.usesCanvasTransform) {
      final current = cache.fillTiles;
      final fullMapVisible = _showsWholeMap(definition, visibleViewBox);
      if (fullMapVisible) {
        // Crossfade: the previous snapshot stays opaque underneath and the
        // new one fades in on top, so no background shows mid-transition.
        final previousPicture = cache.previousFullFillPicture;
        if (previousPicture != null && t < 1) {
          _drawPictureWithAlpha(canvas, previousPicture, alpha);
        }
        _drawPictureWithAlpha(canvas, cache.fullFillPicture, t * alpha);
        _tilesDrawn = current.length;
        return;
      }
      var drewPreviousAny = false;
      var drewCurrentAny = false;
      for (final tile in current) {
        if (visibleViewBox != null &&
            !tile.cullBounds.overlaps(visibleViewBox)) {
          continue;
        }
        final oldPicture = cache.previousFillPictureAt(tile.index);
        var drewPrevious = false;
        var drewCurrent = false;
        if (oldPicture != null && t < 1 && alpha > 0) {
          _drawPictureWithAlpha(
            canvas,
            oldPicture,
            alpha,
            countDrawCall: false,
          );
          drewPrevious = true;
        }
        if (t * alpha > 0) {
          _drawPictureWithAlpha(
            canvas,
            tile.picture,
            t * alpha,
            countDrawCall: false,
          );
          drewCurrent = true;
        }
        if (drewPrevious) drewPreviousAny = true;
        if (drewCurrent) drewCurrentAny = true;
        _tilesDrawn++;
      }
      if (drewPreviousAny) _drawCalls++;
      if (drewCurrentAny) _drawCalls++;
      return;
    }
    for (var i = 0; i < definition.regions.length; i++) {
      final region = definition.regions[i];
      final current = _colorFor(region.id, data);
      final previous = _colorFor(region.id, previousData);
      _fillPaint
        ..style = PaintingStyle.fill
        ..color = _withOpacity(
          Color.lerp(previous, current, t) ?? current,
          alpha,
        );
      canvas.drawPath(cache.paths[i], _fillPaint);
      _drawCalls++;
    }
  }

  void _drawPictureWithAlpha(
    Canvas canvas,
    ui.Picture picture,
    double alpha, {
    bool countDrawCall = true,
  }) {
    final opacity = _clamp01(alpha);
    if (opacity == 0) return;
    if (opacity >= 1) {
      canvas.drawPicture(picture);
      if (countDrawCall) _drawCalls++;
      return;
    }
    _layerPaint.color = _withOpacity(const Color(0xFFFFFFFF), opacity);
    canvas.saveLayer(null, _layerPaint);
    canvas.drawPicture(picture);
    if (countDrawCall) _drawCalls++;
    canvas.restore();
  }

  void _drawTransformed(Canvas canvas, Path path, int index, double scale) {
    if (scale == 1) {
      canvas.drawPath(path, _fillPaint);
      _drawCalls++;
      return;
    }
    final center = cache.centers[index];
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, _fillPaint);
    _drawCalls++;
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
      oldDelegate.entrance != entrance ||
      oldDelegate.camera != camera;
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
    this.camera,
    required this.repaint,
  }) : _cacheVersion = cache.version,
       super(repaint: repaint);

  final MapRenderCache cache;
  final MapDefinition definition;
  final int _cacheVersion;
  final ShapeMapStyle style;
  final Animation<double> progress;
  final ShapeMapEntrance? entrance;
  final ShapeMapCameraController? camera;
  final Listenable repaint;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Paint _tracePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  int _tilesDrawn = 0;

  /// Number of populated spatial tiles visited by the last paint pass.
  @visibleForTesting
  int get tilesDrawn => _tilesDrawn;

  @override
  void paint(Canvas canvas, Size size) {
    _tilesDrawn = 0;
    final hasCamera = camera != null;
    if (hasCamera) {
      canvas.save();
      canvas.translate(camera!.pan.dx, camera!.pan.dy);
      canvas.scale(camera!.scale, camera!.scale);
    }
    final transformed = cache.usesCanvasTransform;
    final visibleViewBox = transformed
        ? cache.visibleViewBox(
            size,
            cameraScale: camera?.scale ?? 1,
            pan: camera?.pan ?? Offset.zero,
          )
        : null;
    if (transformed) canvas.save();
    cache.beginCanvasTransform(canvas);
    final p = progress.value;
    if (p >= 1 || entrance == null) {
      if (transformed) {
        final fullMapVisible =
            cache.fullBorderPicture != null &&
            _showsWholeMap(definition, visibleViewBox);
        if (fullMapVisible) {
          canvas.drawPicture(cache.fullBorderPicture!);
          _tilesDrawn = cache.borderTiles.length;
        } else {
          for (final tile in cache.borderTiles) {
            if (visibleViewBox != null &&
                !tile.cullBounds.overlaps(visibleViewBox)) {
              continue;
            }
            canvas.drawPicture(tile.picture);
            _tilesDrawn++;
          }
        }
      } else {
        canvas.drawPicture(cache.borderPicture);
      }
      if (transformed) canvas.restore();
      if (hasCamera) canvas.restore();
      return;
    }
    final regionProgress = _clamp01(p / _regionPhaseEnd);
    final entranceStyle =
        transformed &&
            (entrance!.style == ShapeMapEntranceStyle.grow ||
                entrance!.style == ShapeMapEntranceStyle.draw)
        ? ShapeMapEntranceStyle.fade
        : entrance!.style;
    _borderPaint
      ..color = style.borderColor
      ..strokeWidth = transformed
          ? style.borderWidth
          : style.borderWidth * cache.transform.scale;
    if (transformed && entranceStyle == ShapeMapEntranceStyle.fade) {
      _borderPaint.color = _withOpacity(style.borderColor, regionProgress);
      canvas.drawPath(cache.largeBorderPath, _borderPaint);
      canvas.restore();
      if (hasCamera) canvas.restore();
      return;
    }
    if (transformed && entranceStyle == ShapeMapEntranceStyle.stagger) {
      final groups = cache.staggerGroupPaths;
      final starts = cache.staggerGroupStarts;
      for (var group = 0; group < groups.length; group++) {
        final local = _clamp01(
          (regionProgress - starts[group]) / _staggerWidth,
        );
        _borderPaint.color = _withOpacity(
          style.borderColor,
          Curves.easeOut.transform(local),
        );
        canvas.drawPath(groups[group], _borderPaint);
      }
      canvas.restore();
      if (hasCamera) canvas.restore();
      return;
    }
    for (var i = 0; i < definition.regions.length; i++) {
      var alpha = regionProgress;
      var scale = 1.0;
      if (entranceStyle == ShapeMapEntranceStyle.stagger) {
        final local = _clamp01(
          (regionProgress - cache.staggerStart(i)) / _staggerWidth,
        );
        final eased = Curves.easeOut.transform(local);
        alpha = eased;
        scale = transformed ? 1 : eased;
      } else if (entranceStyle == ShapeMapEntranceStyle.grow) {
        scale = 0.01 + 0.99 * regionProgress;
      }
      if (entranceStyle == ShapeMapEntranceStyle.draw) {
        final drawT = _clamp01(regionProgress / 0.65);
        final settle = _clamp01((regionProgress - 0.55) / 0.45);
        if (settle > 0) {
          _borderPaint
            ..color = _withOpacity(style.borderColor, settle)
            ..strokeWidth = transformed
                ? style.borderWidth
                : style.borderWidth * cache.transform.scale;
          _drawBorder(canvas, i, 1);
        }
        if (settle < 1) {
          _tracePaint
            ..color = _withOpacity(
              entrance!.drawColor ?? style.marker.fillColor,
              1 - settle,
            )
            ..strokeWidth = transformed
                ? entrance!.drawWidth
                : entrance!.drawWidth * cache.transform.scale;
          _drawPartial(canvas, i, drawT);
        }
      } else {
        _borderPaint.color = _withOpacity(style.borderColor, alpha);
        _drawBorder(canvas, i, scale);
      }
    }
    if (transformed) canvas.restore();
    if (hasCamera) canvas.restore();
  }

  void _drawBorder(Canvas canvas, int index, double scale) {
    final path = cache.paths[index];
    if (cache.usesCanvasTransform) {
      canvas.drawPath(path, _borderPaint);
      return;
    }
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
      oldDelegate.entrance != entrance ||
      oldDelegate.camera != camera ||
      !identical(oldDelegate.repaint, repaint);
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
    this.camera,
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
  final ShapeMapCameraController? camera;
  final Paint _highlightPaint = Paint()..style = PaintingStyle.fill;
  final Paint _selectedBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value < 1) return;
    final id = controller.selectedRegionId ?? controller.hoveredRegionId;
    if (id == null) return;
    final index = definition.indexOf(id);
    if (index < 0) return;
    final selected = controller.selectedRegionId != null;
    final color = selected
        ? style.selectedColor ?? style.hoverColor
        : style.hoverColor;
    if (color == null) return;
    final hasCamera = camera != null;
    if (hasCamera) {
      canvas.save();
      canvas.translate(camera!.pan.dx, camera!.pan.dy);
      canvas.scale(camera!.scale, camera!.scale);
    }
    final opacity = selected ? style.selectedOpacity : 70 / 255;
    _highlightPaint.color = color.withAlpha(
      (color.a * 255 * opacity * animation.value).round().clamp(0, 255),
    );
    if (cache.usesCanvasTransform) canvas.save();
    cache.beginCanvasTransform(canvas);
    canvas.drawPath(cache.paths[index], _highlightPaint);
    if (selected &&
        style.selectedBorderColor != null &&
        style.selectedBorderWidth > 0) {
      _selectedBorderPaint
        ..color = style.selectedBorderColor!
        ..strokeWidth =
            style.selectedBorderWidth /
            ((cache.usesCanvasTransform ? cache.transform.scale : 1) *
                (camera?.scale ?? 1));
      canvas.drawPath(cache.paths[index], _selectedBorderPaint);
    }
    if (cache.usesCanvasTransform) canvas.restore();
    if (hasCamera) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) =>
      !identical(oldDelegate.definition, definition) ||
      !identical(oldDelegate.cache, cache) ||
      oldDelegate._cacheVersion != _cacheVersion ||
      oldDelegate.style != style ||
      !identical(oldDelegate.repaint, repaint) ||
      !identical(oldDelegate.animation, animation) ||
      !identical(oldDelegate.progress, progress) ||
      oldDelegate.camera != camera;
}

const _regionPhaseEnd = 0.78;
const _staggerWidth = 0.35;

double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

/// Whether [visible] (in view-box units) covers the entire map, in which case
/// the single aggregate Picture is cheaper than visiting every tile. The
/// tolerance absorbs floating-point noise from the camera clamp.
bool _showsWholeMap(MapDefinition definition, Rect? visible) {
  if (visible == null) return false;
  const epsilon = 1e-3;
  return visible.left <= epsilon &&
      visible.top <= epsilon &&
      visible.right >= definition.viewBox.width - epsilon &&
      visible.bottom >= definition.viewBox.height - epsilon;
}

Color _withOpacity(Color color, double opacity) =>
    color.withAlpha((color.a * 255 * _clamp01(opacity)).round());
