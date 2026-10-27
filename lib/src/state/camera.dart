import 'package:flutter/animation.dart';
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
  }) {
    final mapLeft = base.offset.dx * scale;
    final mapTop = base.offset.dy * scale;
    final mapWidth = base.scale * viewBox.width * scale;
    final mapHeight = base.scale * viewBox.height * scale;
    final x = mapWidth >= viewport.width
        ? pan.dx.clamp(viewport.width - mapLeft - mapWidth, -mapLeft).toDouble()
        : viewport.width / 2 - mapLeft - mapWidth / 2;
    final y = mapHeight >= viewport.height
        ? pan.dy.clamp(viewport.height - mapTop - mapHeight, -mapTop).toDouble()
        : viewport.height / 2 - mapTop - mapHeight / 2;
    return Offset(x, y);
  }

  /// Calculates a zoom destination centered on [regionBounds].
  static ({double scale, Offset pan}) zoomToRegion({
    required MapTransform base,
    required Size viewBox,
    required Size viewport,
    required Rect regionBounds,
    required double minScale,
    required double maxScale,
    required double padding,
  }) {
    final width = regionBounds.width.abs().clamp(1e-6, double.infinity);
    final height = regionBounds.height.abs().clamp(1e-6, double.infinity);
    final availableWidth = (viewport.width - padding * 2).clamp(
      1e-6,
      double.infinity,
    );
    final availableHeight = (viewport.height - padding * 2).clamp(
      1e-6,
      double.infinity,
    );
    final targetScale = (availableWidth / (base.scale * width))
        .clamp(minScale, maxScale)
        .toDouble();
    final heightScale = (availableHeight / (base.scale * height))
        .clamp(minScale, maxScale)
        .toDouble();
    final scale = targetScale < heightScale ? targetScale : heightScale;
    final pan =
        Offset(viewport.width / 2, viewport.height / 2) -
        (base.offset + regionBounds.center * base.scale) * scale;
    return (
      scale: scale,
      pan: clampPan(
        base: base,
        viewBox: viewBox,
        viewport: viewport,
        scale: scale,
        pan: pan,
      ),
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
    Duration? duration,
    Curve? curve,
  });

  /// Executes a pending reset command.
  void cameraReset({Duration? duration, Curve? curve});
}

class _CameraRequest {
  const _CameraRequest(
    this.kind, {
    this.value,
    this.offset,
    this.focal,
    this.regionId,
    this.padding,
    this.duration,
    this.curve,
  });
  final int kind;
  final double? value;
  final Offset? offset;
  final Offset? focal;
  final String? regionId;
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

  /// Fits [regionId] inside the viewport with [padding] pixels.
  ///
  /// On a country focus map, passing the two-letter country ISO (for example
  /// `BR`) fits [MapDefinition.focusBounds], while an ISO 3166-2 id fits one
  /// admin-1 region.
  void zoomToRegion(
    String regionId, {
    double padding = 16,
    Duration? duration,
    Curve? curve,
  }) {
    _dispatch(
      _CameraRequest(
        3,
        regionId: regionId,
        padding: padding,
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
          duration: request.duration,
          curve: request.curve,
        );
      case 4:
        host.cameraReset(duration: request.duration, curve: request.curve);
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
