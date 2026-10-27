import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../animation/entrance.dart';
import '../data/models.dart';
import '../rendering/markers.dart';
import '../rendering/painters.dart';
import '../rendering/transform.dart';
import '../state/camera.dart';
import '../state/controller.dart';
import '../style/style.dart';

/// Callback invoked when the selected region changes, including programmatic changes.
typedef ShapeMapSelectionCallback = void Function(MapRegion? region);

/// Callback invoked when a region is tapped.
typedef ShapeMapRegionCallback = void Function(MapRegion region);

/// Callback invoked when the hovered region changes.
typedef ShapeMapHoverCallback = void Function(MapRegion? region);

/// Builds a tooltip for a region.
typedef ShapeMapTooltipBuilder =
    Widget Function(
      BuildContext context,
      MapRegion region,
      MapRegionData? data,
    );

/// A performant, animated map rendered from a [MapDefinition].
class ShapeMap extends StatefulWidget {
  /// Creates a shape map.
  const ShapeMap({
    super.key,
    required this.map,
    this.data = const <String, MapRegionData>{},
    this.controller,
    this.cameraController,
    this.zoomEnabled = false,
    this.minScale = 1,
    this.maxScale = 8,
    this.cameraAnimationDuration = const Duration(milliseconds: 250),
    this.cameraAnimationCurve = Curves.easeOut,
    this.style = const ShapeMapStyle(),
    this.markers = const <MapMarkerData>[],
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.entrance,
    this.entranceAnimation,
    this.onRegionTap,
    this.onRegionSelected,
    this.onRegionHover,
    this.tooltipBuilder,
    this.showTooltip = true,
  }) : assert(minScale > 0, 'minScale must be positive'),
       assert(maxScale >= minScale, 'maxScale must be >= minScale'),
       assert(
         entranceAnimation == null || entrance != null,
         'entranceAnimation requires entrance to be configured',
       );

  /// Map geometry to render.
  final MapDefinition map;

  /// Region data keyed by region id.
  final Map<String, MapRegionData> data;

  /// Optional external selection and hover controller.
  final ShapeMapController? controller;

  /// Optional controller for zoom and pan.
  final ShapeMapCameraController? cameraController;

  /// Whether zoom and pan gestures are enabled.
  ///
  /// For maps with more than 1,000 regions, call `await map.warmUp()` before
  /// building this widget so the hit-test spatial index is ready before the
  /// first hover or tap. Enabling double-tap makes simple taps wait for
  /// Flutter's double-tap timeout before being delivered.
  final bool zoomEnabled;

  /// Minimum relative camera scale.
  final double minScale;

  /// Maximum relative camera scale.
  final double maxScale;

  /// Default duration for camera animations.
  final Duration cameraAnimationDuration;

  /// Default curve for camera animations.
  final Curve cameraAnimationCurve;

  /// Visual map configuration.
  final ShapeMapStyle style;

  /// Markers to display above the regions.
  final List<MapMarkerData> markers;

  /// Box fitting strategy.
  final BoxFit fit;

  /// Alignment inside the available box.
  final Alignment alignment;

  /// Duration used for data and marker transitions.
  final Duration animationDuration;

  /// Curve used for transitions.
  final Curve animationCurve;

  /// Optional animation played while the map enters the scene.
  final ShapeMapEntrance? entrance;

  /// Optional externally controlled entrance progress.
  ///
  /// The animation is observed but never advanced or disposed by [ShapeMap].
  final Animation<double>? entranceAnimation;

  /// Called after a region is tapped.
  final ShapeMapRegionCallback? onRegionTap;

  /// Called when the selected region changes.
  final ShapeMapSelectionCallback? onRegionSelected;

  /// Called when hover enters or leaves a region.
  final ShapeMapHoverCallback? onRegionHover;

  /// Optional custom tooltip builder.
  final ShapeMapTooltipBuilder? tooltipBuilder;

  /// Whether the default or custom tooltip should be shown.
  final bool showTooltip;

  @override
  State<ShapeMap> createState() => _ShapeMapState();
}

class _ShapeMapState extends State<ShapeMap>
    with TickerProviderStateMixin
    implements ShapeMapCameraHost {
  late final AnimationController _dataController;
  late final AnimationController _markerController;
  late final AnimationController _highlightController;
  late CurvedAnimation _dataAnimation;
  late CurvedAnimation _markerAnimation;
  late CurvedAnimation _highlightAnimation;
  AnimationController? _entranceController;
  CurvedAnimation? _entranceAnimation;
  late final _EntranceProgress _entranceProgress;
  late final ValueNotifier<bool> _entranceComplete;
  late ShapeMapController _internalController;
  late ShapeMapController _activeController;
  late ShapeMapCameraController _internalCameraController;
  late ShapeMapCameraController _activeCameraController;
  late Map<String, MapRegionData> _previousData;
  late final AnimationController _cameraAnimationController;
  late final ValueNotifier<bool> _cameraSettled;
  late final ValueNotifier<int> _cameraSettleRevision;
  double _cameraStartScale = 1;
  double _cameraTargetScale = 1;
  Offset _cameraStartPan = Offset.zero;
  Offset _cameraTargetPan = Offset.zero;
  Curve _cameraCurve = Curves.linear;
  Timer? _cameraSettleTimer;
  Offset? _lastHoverPosition;
  Offset? _doubleTapPosition;
  double _lastPanZoomScale = 1;
  Offset _lastPanZoomPan = Offset.zero;
  bool _cameraGestureActive = false;
  String? _lastSelectedRegionId;
  MapTransform? _lastLayoutTransform;
  Size? _lastLayoutSize;
  MapDefinition? _lastLayoutMap;
  final MapRenderCache _cache = MapRenderCache();
  final MarkerLayoutCache _markerCache = MarkerLayoutCache();
  Map<String, double> _previousMarkerDiameters = const {};
  Listenable? _fillRepaint;
  Listenable? _highlightRepaint;
  Listenable? _markerRepaint;
  Listenable? _borderRepaint;
  Listenable? _tooltipRepaint;
  bool _animationsDisabled = false;
  bool _cameraRevisionScheduled = false;

  ShapeMapController get _controller => _activeController;

  @override
  void initState() {
    super.initState();
    _internalController = ShapeMapController();
    _activeController = widget.controller ?? _internalController;
    _internalCameraController = ShapeMapCameraController();
    _activeCameraController =
        widget.cameraController ?? _internalCameraController;
    _lastSelectedRegionId = _activeController.selectedRegionId;
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: widget.cameraAnimationDuration,
    )..addListener(_onCameraTick);
    _cameraSettled = ValueNotifier<bool>(true);
    _cameraSettleRevision = ValueNotifier<int>(0);
    _previousData = widget.data;
    _dataController = _createAnimationController(widget.animationDuration);
    _dataController.addStatusListener(_onDataStatusChanged);
    _markerController = _createAnimationController(widget.animationDuration);
    _highlightController = _createAnimationController(
      widget.animationDuration == Duration.zero
          ? Duration.zero
          : const Duration(milliseconds: 150),
    );
    _dataAnimation = CurvedAnimation(
      parent: _dataController,
      curve: widget.animationCurve,
    );
    _markerAnimation = CurvedAnimation(
      parent: _markerController,
      curve: widget.animationCurve,
    );
    _highlightAnimation = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOut,
    );
    _entranceProgress = _EntranceProgress();
    _entranceComplete = ValueNotifier<bool>(widget.entrance == null);
    _entranceProgress.addListener(_onEntranceChanged);
    _configureEntrance();
    _setRepaints();
    _activeController.addListener(_onControllerChanged);
  }

  AnimationController _createAnimationController(Duration duration) {
    return AnimationController(vsync: this, duration: duration, value: 1);
  }

  void _setRepaints() {
    _fillRepaint = Listenable.merge(<Listenable>[
      _dataAnimation,
      _entranceProgress,
      _activeCameraController,
    ]);
    // The highlight only paints once the entrance completes, so it listens to
    // the completion flag instead of every entrance tick.
    _highlightRepaint = Listenable.merge(<Listenable>[
      _activeController,
      _highlightAnimation,
      _entranceComplete,
      _activeCameraController,
    ]);
    _markerRepaint = Listenable.merge(<Listenable>[
      _markerAnimation,
      _entranceProgress,
      _activeCameraController,
    ]);
    _borderRepaint = Listenable.merge(<Listenable>[
      _entranceProgress,
      _activeCameraController,
      _cameraSettled,
    ]);
    _tooltipRepaint = Listenable.merge(<Listenable>[
      _activeController,
      _entranceComplete,
      _cameraSettled,
      _cameraSettleRevision,
    ]);
  }

  void _configureEntrance() {
    final external = widget.entranceAnimation;
    if (external != null) {
      _disposeInternalEntrance();
      _entranceProgress.source = external;
    } else if (widget.entrance != null) {
      if (_entranceController == null) {
        _entranceController = AnimationController(
          vsync: this,
          duration: widget.entrance!.duration,
          value: 0,
        );
        _entranceAnimation = CurvedAnimation(
          parent: _entranceController!,
          curve: widget.entrance!.curve,
        );
        _entranceProgress.source = _entranceAnimation;
        _entranceController!.forward();
      } else {
        _entranceController!.duration = widget.entrance!.duration;
        if (_entranceAnimation!.curve != widget.entrance!.curve) {
          final value = _entranceController!.value;
          _entranceAnimation!.dispose();
          _entranceAnimation = CurvedAnimation(
            parent: _entranceController!,
            curve: widget.entrance!.curve,
          );
          _entranceController!.value = value;
        }
        _entranceProgress.source = _entranceAnimation;
      }
    } else {
      _disposeInternalEntrance();
      _entranceProgress.source = null;
    }
    _onEntranceChanged();
  }

  void _disposeInternalEntrance() {
    _entranceProgress.source = null;
    _entranceAnimation?.dispose();
    _entranceAnimation = null;
    _entranceController?.dispose();
    _entranceController = null;
  }

  void _onEntranceChanged() {
    final complete = _entranceProgress.value >= 1;
    if (_entranceComplete.value != complete) {
      _entranceComplete.value = complete;
    }
  }

  void _updateAnimationsDisabled(bool disabled) {
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    _entranceProgress.disabled = disabled;
    if (disabled && _entranceController != null) {
      _entranceController!.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationsDisabled(
      MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  @override
  void didUpdateWidget(covariant ShapeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _activeController.removeListener(_onControllerChanged);
      _activeController = widget.controller ?? _internalController;
      _lastSelectedRegionId = _activeController.selectedRegionId;
      _activeController.addListener(_onControllerChanged);
      _setRepaints();
    }
    if (oldWidget.cameraController != widget.cameraController) {
      _activeCameraController.detach(this);
      _activeCameraController =
          widget.cameraController ?? _internalCameraController;
      _setRepaints();
    }
    if (oldWidget.animationDuration != widget.animationDuration) {
      _dataController.duration = widget.animationDuration;
      _markerController.duration = widget.animationDuration;
      _highlightController.duration = widget.animationDuration == Duration.zero
          ? Duration.zero
          : const Duration(milliseconds: 150);
    }
    if (oldWidget.animationCurve != widget.animationCurve) {
      _dataAnimation.dispose();
      _markerAnimation.dispose();
      _dataAnimation = CurvedAnimation(
        parent: _dataController,
        curve: widget.animationCurve,
      );
      _markerAnimation = CurvedAnimation(
        parent: _markerController,
        curve: widget.animationCurve,
      );
      _setRepaints();
    }
    if (oldWidget.entranceAnimation != widget.entranceAnimation ||
        oldWidget.entrance != widget.entrance) {
      final wasInternal = oldWidget.entranceAnimation == null;
      _configureEntrance();
      if (wasInternal &&
          widget.entranceAnimation == null &&
          widget.entrance != null &&
          _entranceController != null &&
          !identical(oldWidget.map, widget.map)) {
        _entranceController!.value = 0;
        _entranceController!.forward();
      }
    }

    final mapChanged = !identical(oldWidget.map, widget.map);
    final dataChanged = !mapEquals(oldWidget.data, widget.data);
    final markersChanged = !listEquals(oldWidget.markers, widget.markers);
    if (mapChanged) {
      _previousData = widget.data;
      _previousMarkerDiameters = const {};
      _dataController.value = 1;
      _markerController.value = 1;
      _resetCameraImmediately();
      if (widget.entranceAnimation == null && widget.entrance != null) {
        _entranceController?.value = 0;
        _entranceController?.forward();
      }
    } else {
      if (dataChanged) {
        _previousData = _interpolatedData(_dataAnimation.value);
        _start(_dataController);
      }
      if (markersChanged) {
        final oldDiameters = _markerCache.currentDiameters(
          _markerAnimation.value,
        );
        _previousMarkerDiameters = {
          for (final marker in widget.markers)
            marker.regionId: oldDiameters[marker.regionId] ?? 0,
        };
        _start(_markerController);
      }
    }
    if (widget.animationDuration == Duration.zero) {
      _dataController.value = 1;
      _markerController.value = 1;
      _highlightController.value = 1;
    }
  }

  void _start(AnimationController controller) {
    if (widget.animationDuration == Duration.zero) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  Map<String, MapRegionData> _interpolatedData(double t) {
    final ids = <String>{..._previousData.keys, ...widget.data.keys};
    return {
      for (final id in ids)
        id: MapRegionData(
          fill: Color.lerp(
            _fillFor(id, _previousData),
            _fillFor(id, widget.data),
            t,
          ),
          value: _previousData[id]?.value,
          label: _previousData[id]?.label,
        ),
    };
  }

  Color _fillFor(String id, Map<String, MapRegionData> source) {
    final value = source[id];
    return value?.fill ??
        (value == null ? widget.style.emptyColor : widget.style.dataColor);
  }

  void _onDataStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _cache.completeFillTransition();
    }
  }

  void _onControllerChanged() {
    final selectedId = _controller.selectedRegionId;
    if (selectedId != _lastSelectedRegionId) {
      _lastSelectedRegionId = selectedId;
      widget.onRegionSelected?.call(
        selectedId == null ? null : widget.map.regionById(selectedId),
      );
    }
    if (widget.animationDuration == Duration.zero) {
      _highlightController.value = 1;
    } else {
      _highlightController.forward(from: 0);
    }
  }

  void _onCameraTick() {
    final t = _cameraCurve.transform(_cameraAnimationController.value);
    _updateCamera(
      _cameraStartScale + (_cameraTargetScale - _cameraStartScale) * t,
      Offset.lerp(_cameraStartPan, _cameraTargetPan, t)!,
      isAnimating: true,
    );
    if (_cameraAnimationController.isCompleted) {
      _updateCamera(_cameraTargetScale, _cameraTargetPan);
      _markCameraSettled();
      _scheduleBorderUpdate();
      _refreshHover();
    }
  }

  void _updateCamera(
    double scale,
    Offset pan, {
    bool isAnimating = false,
    bool notify = true,
  }) {
    final size = _lastLayoutSize;
    if (size != null) {
      pan = ShapeMapCameraMath.clampPan(
        base: _cache.transform,
        viewBox: widget.map.viewBox,
        viewport: size,
        scale: scale,
        pan: pan,
      );
    }
    _activeCameraController.updateFromHost(
      scale,
      pan,
      isAnimating: isAnimating,
      notify: notify,
    );
  }

  void _markCameraSettled() {
    _cameraSettled.value = true;
    _cameraSettleRevision.value++;
  }

  void _scheduleCameraRevision() {
    if (_cameraRevisionScheduled) return;
    _cameraRevisionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraRevisionScheduled = false;
      if (!mounted) return;
      _cameraSettleRevision.value++;
    });
  }

  void _animateCamera(
    double scale,
    Offset pan, {
    Duration? duration,
    Curve? curve,
  }) {
    final actualDuration = duration ?? widget.cameraAnimationDuration;
    _cameraCurve = curve ?? widget.cameraAnimationCurve;
    final clampedPan = ShapeMapCameraMath.clampPan(
      base: _cache.transform,
      viewBox: widget.map.viewBox,
      viewport: _lastLayoutSize!,
      scale: scale,
      pan: pan,
    );
    if (_animationsDisabled || actualDuration == Duration.zero) {
      _cameraAnimationController.stop();
      _updateCamera(scale, clampedPan);
      _markCameraSettled();
      _scheduleBorderUpdate();
      _refreshHover();
      return;
    }
    _cameraStartScale = _activeCameraController.scale;
    _cameraStartPan = _activeCameraController.pan;
    _cameraTargetScale = scale;
    _cameraTargetPan = clampedPan;
    _cameraAnimationController.duration = actualDuration;
    _activeCameraController.updateFromHost(
      _activeCameraController.scale,
      _activeCameraController.pan,
      isAnimating: true,
    );
    _cameraSettled.value = false;
    _cameraAnimationController.forward(from: 0);
  }

  void _beginCameraInteraction() {
    _cameraSettleTimer?.cancel();
    _cameraAnimationController.stop();
    _activeCameraController.updateFromHost(
      _activeCameraController.scale,
      _activeCameraController.pan,
    );
    _cameraSettled.value = false;
    _cameraGestureActive = true;
  }

  void _endCameraInteraction() {
    _cameraGestureActive = false;
    _cameraSettleTimer?.cancel();
    _cameraSettleTimer = Timer(const Duration(milliseconds: 50), () {
      _markCameraSettled();
      _scheduleBorderUpdate();
      _refreshHover();
    });
  }

  void _scheduleBorderUpdate() {
    if (_lastLayoutSize == null) return;
    _cache.updateBorder(
      widget.style.borderColor,
      widget.style.borderWidth,
      cameraScale: _activeCameraController.scale,
    );
  }

  Offset _zoomPan(double targetScale, Offset focal) {
    final viewPoint = ShapeMapCameraMath.inverse(
      _cache.transform,
      _activeCameraController.scale,
      _activeCameraController.pan,
      focal,
    );
    return focal -
        (_cache.transform.offset + viewPoint * _cache.transform.scale) *
            targetScale;
  }

  @override
  void cameraZoomTo(
    double scale, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  }) {
    if (_lastLayoutSize == null) return;
    final targetScale = scale
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    final point =
        focal ??
        Offset(_lastLayoutSize!.width / 2, _lastLayoutSize!.height / 2);
    _animateCamera(
      targetScale,
      _zoomPan(targetScale, point),
      duration: duration,
      curve: curve,
    );
  }

  @override
  void cameraZoomBy(
    double factor, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  }) {
    if (factor <= 0 || _lastLayoutSize == null) return;
    cameraZoomTo(
      _activeCameraController.scale * factor,
      focal: focal,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void cameraPanBy(Offset delta) {
    if (_lastLayoutSize == null) return;
    _beginCameraInteraction();
    _updateCamera(
      _activeCameraController.scale,
      _activeCameraController.pan + delta,
    );
    _endCameraInteraction();
  }

  @override
  void cameraZoomToRegion(
    String regionId, {
    double padding = 16,
    Duration? duration,
    Curve? curve,
  }) {
    if (_lastLayoutSize == null) return;
    final region = widget.map.regionById(regionId);
    if (region == null) return;
    final destination = ShapeMapCameraMath.zoomToRegion(
      base: _cache.transform,
      viewBox: widget.map.viewBox,
      viewport: _lastLayoutSize!,
      regionBounds: region.bounds,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      padding: padding,
    );
    _animateCamera(
      destination.scale,
      destination.pan,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void cameraReset({Duration? duration, Curve? curve}) {
    if (_lastLayoutSize == null) return;
    _animateCamera(
      widget.minScale.clamp(1, widget.maxScale).toDouble(),
      Offset.zero,
      duration: duration,
      curve: curve,
    );
  }

  void _resetCameraImmediately() {
    _cameraAnimationController.stop();
    _markCameraSettled();
    _activeCameraController.updateFromHost(1, Offset.zero);
  }

  void _refreshHover() {
    final position = _lastHoverPosition;
    if (position == null || _entranceProgress.value < 1) return;
    _hoverAt(position);
  }

  void _hoverAt(Offset position) {
    final region = _hitTest(position);
    if (region == null && _entranceProgress.value < 1) return;
    final old = _controller.hoveredRegionId;
    _controller.setHovered(region?.id);
    if (old != region?.id) widget.onRegionHover?.call(region);
  }

  @override
  void dispose() {
    _activeController.removeListener(_onControllerChanged);
    _dataController.removeStatusListener(_onDataStatusChanged);
    _markerCache.dispose();
    _cache.dispose();
    _dataAnimation.dispose();
    _markerAnimation.dispose();
    _highlightAnimation.dispose();
    _disposeInternalEntrance();
    _entranceProgress.removeListener(_onEntranceChanged);
    _entranceComplete.dispose();
    _entranceProgress.dispose();
    _dataController.dispose();
    _markerController.dispose();
    _highlightController.dispose();
    _activeCameraController.detach(this);
    _cameraSettleTimer?.cancel();
    _cameraSettled.dispose();
    _cameraSettleRevision.dispose();
    _cameraAnimationController.dispose();
    _internalCameraController.dispose();
    _internalController.dispose();
    super.dispose();
  }

  MapRegion? _hitTest(Offset point) {
    if (_entranceProgress.value < 1) return null;
    final cameraPoint = ShapeMapCameraMath.inverse(
      _cache.transform,
      _activeCameraController.scale,
      _activeCameraController.pan,
      point,
    );
    return widget.map.hitTest(cameraPoint);
  }

  void _tap(TapUpDetails details) {
    final region = _hitTest(details.localPosition);
    if (_entranceProgress.value < 1) return;
    _controller.select(region?.id);
    if (region != null) widget.onRegionTap?.call(region);
  }

  void _hover(PointerHoverEvent event) {
    _lastHoverPosition = event.localPosition;
    if (!_cameraSettled.value) return;
    _hoverAt(event.localPosition);
  }

  double _lastGestureScale = 1;

  void _onScaleStart(ScaleStartDetails details) {
    if (_entranceProgress.value >= 1) _beginCameraInteraction();
    _lastGestureScale = 1;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_entranceProgress.value < 1) return;
    final currentScale = _activeCameraController.scale;
    final nextScale = (currentScale * details.scale / _lastGestureScale)
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    _lastGestureScale = details.scale;
    _updateCamera(
      nextScale,
      _zoomPan(nextScale, details.localFocalPoint) + details.focalPointDelta,
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_cameraGestureActive) _endCameraInteraction();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    if (_entranceProgress.value < 1 || _doubleTapPosition == null) return;
    final target = _activeCameraController.scale >= widget.maxScale
        ? 1.0
        : _activeCameraController.scale * 2;
    cameraZoomTo(target, focal: _doubleTapPosition);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _entranceProgress.value < 1) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final factor = math.exp(-event.scrollDelta.dy * 0.01).toDouble();
      cameraZoomBy(factor, focal: event.localPosition);
    });
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    if (_entranceProgress.value >= 1) {
      _beginCameraInteraction();
      _lastPanZoomScale = 1;
      _lastPanZoomPan = Offset.zero;
    }
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (_entranceProgress.value < 1) return;
    final scaleRatio = event.scale / _lastPanZoomScale;
    final nextScale = (_activeCameraController.scale * scaleRatio)
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    final panDelta = event.pan - _lastPanZoomPan;
    _lastPanZoomScale = event.scale;
    _lastPanZoomPan = event.pan;
    _updateCamera(
      nextScale,
      _zoomPan(nextScale, event.localPosition) + panDelta,
    );
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    if (_cameraGestureActive) _endCameraInteraction();
  }

  @override
  Widget build(BuildContext context) {
    _updateAnimationsDisabled(
      MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        final previousTransform = _lastLayoutTransform;
        final previousSize = _lastLayoutSize;
        final previousMap = _lastLayoutMap;
        _cache.update(widget.map, size, widget.fit, widget.alignment);
        _lastLayoutTransform = _cache.transform;
        _lastLayoutSize = size;
        _lastLayoutMap = widget.map;
        _activeCameraController.attach(this);
        if (previousTransform != null &&
            previousSize != null &&
            previousSize != size &&
            identical(previousMap, widget.map)) {
          final point = ShapeMapCameraMath.inverse(
            previousTransform,
            _activeCameraController.scale,
            _activeCameraController.pan,
            Offset(previousSize.width / 2, previousSize.height / 2),
          );
          _updateCamera(
            _activeCameraController.scale,
            Offset(size.width / 2, size.height / 2) -
                (_cache.transform.offset + point * _cache.transform.scale) *
                    _activeCameraController.scale,
            notify: false,
          );
          _scheduleCameraRevision();
        }
        _cache.updateFillBatches(
          widget.data,
          widget.style.emptyColor,
          widget.style.dataColor,
        );
        if (_dataController.value >= 1) {
          _cache.completeFillTransition();
        }
        if (widget.entrance?.style == ShapeMapEntranceStyle.stagger) {
          _cache.updateStagger(widget.entrance!.staggerOrder);
        } else if (widget.entrance?.style == ShapeMapEntranceStyle.draw &&
            !_cache.usesCanvasTransform) {
          // Prepared even at 100%: an external controller can replay the
          // entrance without rebuilding this widget.
          _cache.prepareDraw();
        }
        _cache.updateBorder(
          widget.style.borderColor,
          widget.style.borderWidth,
          cameraScale: _activeCameraController.scale,
        );
        _markerCache.update(
          widget.map,
          widget.markers,
          widget.style.marker,
          _previousMarkerDiameters,
        );
        return ClipRect(
          child: Listener(
            onPointerSignal: widget.zoomEnabled ? _onPointerSignal : null,
            onPointerPanZoomStart: widget.zoomEnabled ? _onPanZoomStart : null,
            onPointerPanZoomUpdate: widget.zoomEnabled
                ? _onPanZoomUpdate
                : null,
            onPointerPanZoomEnd: widget.zoomEnabled ? _onPanZoomEnd : null,
            child: MouseRegion(
              onHover: _hover,
              onExit: (_) {
                if (_entranceProgress.value < 1) return;
                _controller.setHovered(null);
                widget.onRegionHover?.call(null);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _tap,
                onScaleStart: widget.zoomEnabled ? _onScaleStart : null,
                onScaleUpdate: widget.zoomEnabled ? _onScaleUpdate : null,
                onScaleEnd: widget.zoomEnabled ? _onScaleEnd : null,
                onDoubleTapDown: widget.zoomEnabled ? _onDoubleTapDown : null,
                onDoubleTap: widget.zoomEnabled ? _onDoubleTap : null,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: RegionFillPainter(
                          definition: widget.map,
                          cache: _cache,
                          data: widget.data,
                          previousData: _previousData,
                          style: widget.style,
                          animation: _dataAnimation,
                          progress: _entranceProgress,
                          entrance: widget.entrance,
                          repaint: _fillRepaint!,
                          camera: _activeCameraController,
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: RegionBorderPainter(
                          cache: _cache,
                          definition: widget.map,
                          style: widget.style,
                          progress: _entranceProgress,
                          entrance: widget.entrance,
                          camera: _activeCameraController,
                          repaint: _borderRepaint!,
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: HighlightPainter(
                          cache: _cache,
                          definition: widget.map,
                          controller: _controller,
                          style: widget.style,
                          repaint: _highlightRepaint!,
                          animation: _highlightAnimation,
                          progress: _entranceProgress,
                          camera: _activeCameraController,
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: MarkerPainter(
                          cache: _cache,
                          layoutCache: _markerCache,
                          style: widget.style.marker,
                          animation: _markerAnimation,
                          progress: _entranceProgress,
                          entrance: widget.entrance,
                          repaint: _markerRepaint!,
                          camera: _activeCameraController,
                        ),
                      ),
                    ),
                    if (widget.showTooltip)
                      ListenableBuilder(
                        listenable: _tooltipRepaint!,
                        builder: (context, child) {
                          if (!_entranceComplete.value ||
                              !_cameraSettled.value) {
                            return const SizedBox.shrink();
                          }
                          return _TooltipLayer(
                            map: widget.map,
                            data: widget.data,
                            markers: widget.markers,
                            controller: _controller,
                            cache: _cache,
                            camera: _activeCameraController,
                            style: widget.style.tooltip,
                            builder: widget.tooltipBuilder,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EntranceProgress extends ChangeNotifier implements Animation<double> {
  Animation<double>? _source;
  final List<AnimationStatusListener> _statusListeners = [];
  bool _disabled = false;

  Animation<double>? get source => _source;

  set source(Animation<double>? value) {
    if (identical(_source, value)) return;
    _source?.removeListener(_handleSourceChanged);
    _source?.removeStatusListener(_handleSourceStatusChanged);
    _source = value;
    _source?.addListener(_handleSourceChanged);
    _source?.addStatusListener(_handleSourceStatusChanged);
    notifyListeners();
  }

  bool get disabled => _disabled;

  set disabled(bool value) {
    if (_disabled == value) return;
    _disabled = value;
    notifyListeners();
  }

  @override
  double get value {
    if (_disabled) return 1;
    final sourceValue = _source?.value ?? 1;
    return sourceValue.clamp(0.0, 1.0).toDouble();
  }

  @override
  bool get isAnimating =>
      status == AnimationStatus.forward || status == AnimationStatus.reverse;

  @override
  bool get isCompleted => status == AnimationStatus.completed;

  @override
  bool get isDismissed => status == AnimationStatus.dismissed;

  @override
  bool get isForwardOrCompleted =>
      status == AnimationStatus.forward || status == AnimationStatus.completed;

  @override
  String toStringDetails() => 'value: $value, status: $status';

  @override
  Animation<U> drive<U>(Animatable<U> child) => child.animate(this);

  @override
  AnimationStatus get status => _disabled
      ? AnimationStatus.completed
      : (_source?.status ?? AnimationStatus.completed);

  @override
  void addStatusListener(AnimationStatusListener listener) {
    _statusListeners.add(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void _handleSourceChanged() => notifyListeners();

  void _handleSourceStatusChanged(AnimationStatus status) {
    for (final listener in List<AnimationStatusListener>.of(_statusListeners)) {
      listener(status);
    }
  }

  @override
  void dispose() {
    source = null;
    _statusListeners.clear();
    super.dispose();
  }
}

class _TooltipLayer extends StatelessWidget {
  const _TooltipLayer({
    required this.map,
    required this.data,
    required this.markers,
    required this.controller,
    required this.cache,
    required this.camera,
    required this.style,
    this.builder,
  });

  final MapDefinition map;
  final Map<String, MapRegionData> data;
  final List<MapMarkerData> markers;
  final ShapeMapController controller;
  final MapRenderCache cache;
  final ShapeMapCameraController camera;
  final TooltipStyle style;
  final ShapeMapTooltipBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final id = controller.selectedRegionId ?? controller.hoveredRegionId;
    if (id == null) return const SizedBox.shrink();
    final region = map.regionById(id);
    if (region == null) return const SizedBox.shrink();
    final regionData = data[id];
    final child =
        builder?.call(context, region, regionData) ??
        _defaultTooltip(region, regionData, style);
    MapMarkerData? marker;
    for (final item in markers) {
      if (item.regionId == id) {
        marker = item;
        break;
      }
    }
    final position =
        camera.pan +
        (cache.transform.offset +
                (marker?.position ?? region.markerAnchor) *
                    cache.transform.scale) *
            camera.scale;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _TooltipLayoutDelegate(position),
          child: child,
        ),
      ),
    );
  }

  Widget _defaultTooltip(
    MapRegion region,
    MapRegionData? data,
    TooltipStyle style,
  ) {
    final suffix = data?.value == null ? '' : ': ${data!.value}';
    final name = data?.label?.isNotEmpty == true ? data!.label! : region.name;
    return DecoratedBox(
      key: const ValueKey<String>('shape-map-tooltip'),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(style.borderRadius),
      ),
      child: Padding(
        padding: style.padding,
        child: Text(
          '$name$suffix',
          style: style.textStyle.copyWith(color: style.textColor),
        ),
      ),
    );
  }
}

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  _TooltipLayoutDelegate(this.position);
  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final desired =
        position + const Offset(8, -8) - Offset(0, childSize.height);
    return Offset(
      math.max(0, math.min(desired.dx, size.width - childSize.width)),
      math.max(0, math.min(desired.dy, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(covariant _TooltipLayoutDelegate oldDelegate) =>
      oldDelegate.position != position;
}
