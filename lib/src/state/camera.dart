import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../rendering/transform.dart';

/// Computes camera coordinates without depending on a widget binding.
class ShapeMapCameraMath {
  /// Applies a camera to a view-box point using the fitted [base] transform.
  static Offset apply(
    MapTransform base,
    double scale,
    Offset pan,
    Offset point,
  ) => pan + (base.offset + point * base.scale) * scale;

  /// Inverts a camera and base transform to a view-box point.
  static Offset inverse(
    MapTransform base,
    double scale,
    Offset pan,
    Offset screenPoint,
  ) => base.inverse((screenPoint - pan) / scale);

  /// Clamps [pan] so the camera cannot reveal empty space outside the map.
  ///
  /// If the map is smaller than the viewport on an axis, it is centered on
  /// that axis. This keeps the default contain layout unchanged at scale 1.
  static Offset clampPan({
    required MapTransform base,
    required Size viewBox,
    required Size viewport,
    required double scale,
    required Offset pan,
    EdgeInsets insets = EdgeInsets.zero,
  }) {
    final visible = _insetViewport(viewport, insets);
    final mapLeft = base.offset.dx * scale;
    final mapTop = base.offset.dy * scale;
    final mapWidth = base.scale * viewBox.width * scale;
    final mapHeight = base.scale * viewBox.height * scale;
    final x = mapWidth >= visible.width
        ? pan.dx
              .clamp(visible.right - mapLeft - mapWidth, visible.left - mapLeft)
              .toDouble()
        : insets != EdgeInsets.zero
        ? pan.dx
              .clamp(visible.left - mapLeft - mapWidth, visible.right - mapLeft)
              .toDouble()
        : visible.center.dx - mapLeft - mapWidth / 2;
    final y = mapHeight >= visible.height
        ? pan.dy
              .clamp(visible.bottom - mapTop - mapHeight, visible.top - mapTop)
              .toDouble()
        : insets != EdgeInsets.zero
        ? pan.dy
              .clamp(visible.top - mapTop - mapHeight, visible.bottom - mapTop)
              .toDouble()
        : visible.center.dy - mapTop - mapHeight / 2;
    return Offset(x, y);
  }

  /// Calculates a zoom destination centered on [viewBoxBounds].
  static ({double scale, Offset pan}) zoomToBounds({
    required MapTransform base,
    required Size viewBox,
    required Size viewport,
    required Rect viewBoxBounds,
    required double minScale,
    required double maxScale,
    EdgeInsets insets = EdgeInsets.zero,
    double padding = 16,
  }) {
    final visible = _insetViewport(viewport, insets);
    final target = _paddedRect(visible, padding);
    final width = viewBoxBounds.width.abs().clamp(1e-6, double.infinity);
    final height = viewBoxBounds.height.abs().clamp(1e-6, double.infinity);
    final widthScale = (target.width / (base.scale * width))
        .clamp(minScale, maxScale)
        .toDouble();
    final heightScale = (target.height / (base.scale * height))
        .clamp(minScale, maxScale)
        .toDouble();
    final scale = widthScale < heightScale ? widthScale : heightScale;
    final pan =
        target.center -
        (base.offset + viewBoxBounds.center * base.scale) * scale;
    return (
      scale: scale,
      pan: clampPan(
        base: base,
        viewBox: viewBox,
        viewport: viewport,
        scale: scale,
        pan: pan,
        insets: insets,
      ),
    );
  }

  /// Calculates a zoom destination centered on [regionBounds].
  static ({double scale, Offset pan}) zoomToRegion({
    required MapTransform base,
    required Size viewBox,
    required Size viewport,
    required Rect regionBounds,
    required double minScale,
    required double maxScale,
    double padding = 16,
    EdgeInsets insets = EdgeInsets.zero,
  }) => zoomToBounds(
    base: base,
    viewBox: viewBox,
    viewport: viewport,
    viewBoxBounds: regionBounds,
    minScale: minScale,
    maxScale: maxScale,
    insets: insets,
    padding: padding,
  );

  static Rect _insetViewport(Size viewport, EdgeInsets insets) {
    final left = insets.left.clamp(0, viewport.width).toDouble();
    final top = insets.top.clamp(0, viewport.height).toDouble();
    final right = insets.right.clamp(0, viewport.width - left).toDouble();
    final bottom = insets.bottom.clamp(0, viewport.height - top).toDouble();
    return Rect.fromLTWH(
      left,
      top,
      (viewport.width - left - right).clamp(1e-6, double.infinity).toDouble(),
      (viewport.height - top - bottom).clamp(1e-6, double.infinity).toDouble(),
    );
  }

  static Rect _paddedRect(Rect rect, double padding) {
    final horizontal = padding.clamp(0, rect.width / 2).toDouble();
    final vertical = padding.clamp(0, rect.height / 2).toDouble();
    return Rect.fromLTWH(
      rect.left + horizontal,
      rect.top + vertical,
      (rect.width - horizontal * 2).clamp(1e-6, double.infinity).toDouble(),
      (rect.height - vertical * 2).clamp(1e-6, double.infinity).toDouble(),
    );
  }
}

/// Internal binding implemented by [ShapeMap] to drive a camera ticker.
abstract interface class ShapeMapCameraHost {
  /// Executes a pending zoom command.
  void cameraZoomTo(
    double scale, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  });

  /// Executes a pending relative zoom command.
  void cameraZoomBy(
    double factor, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  });

  /// Executes a pending pan command.
  void cameraPanBy(Offset delta);

  /// Executes a pending region-fit command.
  void cameraZoomToRegion(
    String regionId, {
    double padding,
    EdgeInsets insets,
    Duration? duration,
    Curve? curve,
  });

  /// Executes a pending bounds-fit command.
  void cameraZoomToBounds(
    Rect viewBoxBounds, {
    EdgeInsets insets,
    double padding,
    Duration? duration,
    Curve? curve,
  });

  /// Executes a pending reset command.
  void cameraReset({Duration? duration, Curve? curve});

  /// Converts a viewport point to view-box coordinates, or null before layout.
  Offset? cameraViewBoxPoint(Offset viewportPoint);

  /// The view-box rectangle currently visible, or null before layout.
  Rect? cameraVisibleViewBox();

  /// The size of the attached viewport, or null before layout.
  Size? get cameraViewportSize;
}

class _CameraRequest {
  const _CameraRequest(
    this.kind, {
    this.value,
    this.offset,
    this.focal,
    this.regionId,
    this.bounds,
    this.insets = EdgeInsets.zero,
    this.padding,
    this.duration,
    this.curve,
  });
  final int kind;
  final double? value;
  final Offset? offset;
  final Offset? focal;
  final String? regionId;
  final Rect? bounds;
  final EdgeInsets insets;
  final double? padding;
  final Duration? duration;
  final Curve? curve;
}

/// Controls zoom and pan for a [ShapeMap].
///
/// The widget owns the ticker used for animations. An external controller is
/// never disposed by the widget and may receive commands before its first
/// layout; those commands are applied as soon as the map is attached.
class ShapeMapCameraController extends ChangeNotifier {
  ShapeMapCameraHost? _host;
  _CameraRequest? _pending;
  double _scale = 1;
  Offset _pan = Offset.zero;
  bool _isAnimating = false;

  /// Current zoom relative to the map's fitted scale.
  double get scale => _scale;

  /// Current pan in viewport pixels.
  Offset get pan => _pan;

  /// Whether a camera animation is running.
  bool get isAnimating => _isAnimating;

  /// Converts a point in viewport pixels to map view-box coordinates.
  ///
  /// Returns null while no [ShapeMap] is attached or laid out. Combine with
  /// `MapDefinition.hitTest` to find the region under a viewport point, for
  /// example the region at the viewport center after a zoom gesture.
  Offset? viewBoxPointAt(Offset viewportPoint) =>
      _host?.cameraViewBoxPoint(viewportPoint);

  /// The part of the map view box currently visible, or null before layout.
  Rect? get visibleViewBox => _host?.cameraVisibleViewBox();

  /// The attached viewport size, or null before layout.
  Size? get viewportSize => _host?.cameraViewportSize;

  /// Zooms to an absolute relative [scale], optionally around [focal].
  void zoomTo(double scale, {Offset? focal, Duration? duration, Curve? curve}) {
    _dispatch(
      _CameraRequest(
        0,
        value: scale,
        focal: focal,
        duration: duration,
        curve: curve,
      ),
    );
  }

  /// Multiplies the current zoom by [factor], optionally around [focal].
  void zoomBy(
    double factor, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  }) {
    _dispatch(
      _CameraRequest(
        1,
        value: factor,
        focal: focal,
        duration: duration,
        curve: curve,
      ),
    );
  }

  /// Moves the map by [delta] viewport pixels.
  void panBy(Offset delta) => _dispatch(_CameraRequest(2, offset: delta));

  /// Fits [viewBoxBounds] inside the viewport, excluding [insets].
  ///
  /// The fitted bounds are centered in the remaining visible rectangle and
  /// receive [padding] on each side.
  void zoomToBounds(
    Rect viewBoxBounds, {
    EdgeInsets insets = EdgeInsets.zero,
    double padding = 16,
    Duration? duration,
    Curve? curve,
  }) {
    _dispatch(
      _CameraRequest(
        5,
        bounds: viewBoxBounds,
        insets: insets,
        padding: padding,
        duration: duration,
        curve: curve,
      ),
    );
  }

  /// Fits [regionId] inside the viewport with [padding] pixels.
  ///
  /// [insets] describes viewport areas covered by overlays. The symmetric
  /// [padding] behavior remains available for callers that do not use
  /// overlays.
  ///
  /// On a country focus map, passing the two-letter country ISO (for example
  /// `BR`) fits [MapDefinition.focusBounds], while an ISO 3166-2 id fits one
  /// admin-1 region.
  void zoomToRegion(
    String regionId, {
    double padding = 16,
    EdgeInsets insets = EdgeInsets.zero,
    Duration? duration,
    Curve? curve,
  }) {
    _dispatch(
      _CameraRequest(
        3,
        regionId: regionId,
        padding: padding,
        insets: insets,
        duration: duration,
        curve: curve,
      ),
    );
  }

  /// Returns to the initial fitted camera.
  void resetZoom({Duration? duration, Curve? curve}) {
    _dispatch(_CameraRequest(4, duration: duration, curve: curve));
  }

  void _dispatch(_CameraRequest request) {
    final host = _host;
    if (host == null) {
      _pending = request;
      return;
    }
    _send(host, request);
  }

  void _send(ShapeMapCameraHost host, _CameraRequest request) {
    switch (request.kind) {
      case 0:
        host.cameraZoomTo(
          request.value!,
          focal: request.focal,
          duration: request.duration,
          curve: request.curve,
        );
      case 1:
        host.cameraZoomBy(
          request.value!,
          focal: request.focal,
          duration: request.duration,
          curve: request.curve,
        );
      case 2:
        host.cameraPanBy(request.offset!);
      case 3:
        host.cameraZoomToRegion(
          request.regionId!,
          padding: request.padding!,
          insets: request.insets,
          duration: request.duration,
          curve: request.curve,
        );
      case 4:
        host.cameraReset(duration: request.duration, curve: request.curve);
      case 5:
        host.cameraZoomToBounds(
          request.bounds!,
          insets: request.insets,
          padding: request.padding!,
          duration: request.duration,
          curve: request.curve,
        );
    }
  }

  /// Attaches the widget-side animation binding.
  void attach(ShapeMapCameraHost host) {
    _host = host;
    final pending = _pending;
    _pending = null;
    if (pending != null) _send(host, pending);
  }

  /// Detaches a widget-side animation binding without disposing this object.
  void detach(ShapeMapCameraHost host) {
    if (identical(_host, host)) _host = null;
  }

  /// Updates the immutable camera state and notifies only on actual changes.
  @internal
  void updateFromHost(
    double scale,
    Offset pan, {
    bool isAnimating = false,
    bool notify = true,
  }) {
    final changed = _scale != scale || _pan != pan;
    _scale = scale;
    _pan = pan;
    _isAnimating = isAnimating;
    if (changed && notify) notifyListeners();
  }
}
