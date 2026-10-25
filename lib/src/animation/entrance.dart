import 'package:flutter/animation.dart';

import '../data/models.dart';

/// The visual effect used while a map enters the scene.
enum ShapeMapEntranceStyle { fade, grow, stagger, draw }

/// The order in which regions enter when using [ShapeMapEntranceStyle.stagger].
enum ShapeMapStaggerOrder {
  /// Uses the order in [MapDefinition.regions].
  mapOrder,

  /// Starts with the region nearest the top of the map.
  topToBottom,

  /// Starts with the region nearest the bottom of the map.
  bottomToTop,

  /// Starts with the region nearest the left of the map.
  leftToRight,

  /// Starts with the region nearest the right of the map.
  rightToLeft,
}

/// Configuration for the animation played when a [ShapeMap] appears.
class ShapeMapEntrance {
  /// Creates an entrance animation configuration.
  const ShapeMapEntrance({
    this.style = ShapeMapEntranceStyle.fade,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOut,
    this.staggerOrder = ShapeMapStaggerOrder.topToBottom,
    this.drawColor,
    this.drawWidth = 1.5,
  });

  /// Color of the outline traced by [ShapeMapEntranceStyle.draw].
  ///
  /// Defaults to [MarkerStyle.fillColor] so the trace stays visible even when
  /// the regular border color blends with the background. The trace fades out
  /// as the fill and the regular border fade in.
  final Color? drawColor;

  /// Width, in view-box units, of the outline traced by
  /// [ShapeMapEntranceStyle.draw].
  final double drawWidth;

  /// The visual effect used for region entry.
  final ShapeMapEntranceStyle style;

  /// Duration of an internally controlled entrance animation.
  final Duration duration;

  /// Curve applied to the internally controlled animation.
  final Curve curve;

  /// Region ordering used by the stagger effect.
  final ShapeMapStaggerOrder staggerOrder;

  @override
  bool operator ==(Object other) =>
      other is ShapeMapEntrance &&
      other.style == style &&
      other.duration == duration &&
      other.curve == curve &&
      other.staggerOrder == staggerOrder &&
      other.drawColor == drawColor &&
      other.drawWidth == drawWidth;

  @override
  int get hashCode =>
      Object.hash(style, duration, curve, staggerOrder, drawColor, drawWidth);
}
