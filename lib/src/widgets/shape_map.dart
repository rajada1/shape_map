import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../animation/entrance.dart';
import '../data/models.dart';
import '../rendering/markers.dart';
import '../rendering/painters.dart';
import '../rendering/transform.dart';
import '../state/controller.dart';
import '../style/style.dart';

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
    this.style = const ShapeMapStyle(),
    this.markers = const <MapMarkerData>[],
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.entrance,
    this.entranceAnimation,
    this.onRegionTap,
    this.onRegionHover,
    this.tooltipBuilder,
    this.showTooltip = true,
  }) : assert(
         entranceAnimation == null || entrance != null,
         'entranceAnimation requires entrance to be configured',
       );

  /// Map geometry to render.
  final MapDefinition map;

  /// Region data keyed by region id.
  final Map<String, MapRegionData> data;

  /// Optional external selection and hover controller.
  final ShapeMapController? controller;

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

  /// Called when hover enters or leaves a region.
  final ShapeMapHoverCallback? onRegionHover;

  /// Optional custom tooltip builder.
  final ShapeMapTooltipBuilder? tooltipBuilder;

  /// Whether the default or custom tooltip should be shown.
  final bool showTooltip;

  @override
  State<ShapeMap> createState() => _ShapeMapState();
}

class _ShapeMapState extends State<ShapeMap> with TickerProviderStateMixin {
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
  late Map<String, MapRegionData> _previousData;
  final MapRenderCache _cache = MapRenderCache();
  final MarkerLayoutCache _markerCache = MarkerLayoutCache();
  Map<String, double> _previousMarkerDiameters = const {};
  Listenable? _fillRepaint;
  Listenable? _highlightRepaint;
  Listenable? _markerRepaint;
  Listenable? _tooltipRepaint;
  bool _animationsDisabled = false;

  ShapeMapController get _controller => _activeController;

  @override
  void initState() {
    super.initState();
    _internalController = ShapeMapController();
    _activeController = widget.controller ?? _internalController;
    _previousData = widget.data;
    _dataController = _createAnimationController(widget.animationDuration);
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
    ]);
    // The highlight only paints once the entrance completes, so it listens to
    // the completion flag instead of every entrance tick.
    _highlightRepaint = Listenable.merge(<Listenable>[
      _activeController,
      _highlightAnimation,
      _entranceComplete,
    ]);
    _markerRepaint = Listenable.merge(<Listenable>[
      _markerAnimation,
      _entranceProgress,
    ]);
    _tooltipRepaint = Listenable.merge(<Listenable>[
      _activeController,
      _entranceComplete,
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
      _activeController.addListener(_onControllerChanged);
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

  void _onControllerChanged() {
    if (widget.animationDuration == Duration.zero) {
      _highlightController.value = 1;
    } else {
      _highlightController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _activeController.removeListener(_onControllerChanged);
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
    _internalController.dispose();
    super.dispose();
  }

  MapRegion? _hitTest(Offset point) {
    if (_entranceProgress.value < 1) return null;
    final inverse = _cache.transform.inverse(point);
    for (var i = widget.map.regions.length - 1; i >= 0; i--) {
      final region = widget.map.regions[i];
      if (!region.bounds.contains(inverse)) continue;
      if (region.geometry.path.contains(inverse)) return region;
    }
    return null;
  }

  void _tap(TapUpDetails details) {
    final region = _hitTest(details.localPosition);
    if (_entranceProgress.value < 1) return;
    _controller.select(region?.id);
    if (region != null) widget.onRegionTap?.call(region);
  }

  void _hover(PointerHoverEvent event) {
    final region = _hitTest(event.localPosition);
    if (region == null && _entranceProgress.value < 1) return;
    final old = _controller.hoveredRegionId;
    _controller.setHovered(region?.id);
    if (old != region?.id) widget.onRegionHover?.call(region);
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
        _cache.update(widget.map, size, widget.fit, widget.alignment);
        if (widget.entrance?.style == ShapeMapEntranceStyle.stagger) {
          _cache.updateStagger(widget.entrance!.staggerOrder);
        } else if (widget.entrance?.style == ShapeMapEntranceStyle.draw) {
          // Prepared even at 100%: an external controller can replay the
          // entrance without rebuilding this widget.
          _cache.prepareDraw();
        }
        _cache.updateBorder(widget.style.borderColor, widget.style.borderWidth);
        _markerCache.update(
          widget.map,
          widget.markers,
          widget.style.marker,
          _previousMarkerDiameters,
        );
        return MouseRegion(
          onHover: _hover,
          onExit: (_) {
            if (_entranceProgress.value < 1) return;
            _controller.setHovered(null);
            widget.onRegionHover?.call(null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _tap,
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
                    ),
                  ),
                ),
                if (widget.showTooltip)
                  ListenableBuilder(
                    listenable: _tooltipRepaint!,
                    builder: (context, child) {
                      if (!_entranceComplete.value) {
                        return const SizedBox.shrink();
                      }
                      return _TooltipLayer(
                        map: widget.map,
                        data: widget.data,
                        markers: widget.markers,
                        controller: _controller,
                        cache: _cache,
                        style: widget.style.tooltip,
                        builder: widget.tooltipBuilder,
                      );
                    },
                  ),
              ],
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
    required this.style,
    this.builder,
  });

  final MapDefinition map;
  final Map<String, MapRegionData> data;
  final List<MapMarkerData> markers;
  final ShapeMapController controller;
  final MapRenderCache cache;
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
    final position = cache.transform.forward(
      marker?.position ?? region.markerAnchor,
    );
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
