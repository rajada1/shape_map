import 'package:flutter/material.dart';

/// Controls linear marker diameter interpolation.
class MarkerScale {
  /// Creates a scale from [minDiameter] to [maxDiameter].
  const MarkerScale({
    this.minValue = 0,
    this.maxValue = 100,
    this.minDiameter = 10,
    this.maxDiameter = 49,
  });

  /// Minimum input value.
  final num minValue;

  /// Maximum input value.
  final num maxValue;

  /// Diameter at [minValue].
  final double minDiameter;

  /// Diameter at [maxValue].
  final double maxDiameter;

  /// Calculates a clamped linearly interpolated diameter.
  double diameterFor(num value) {
    if (maxValue == minValue) return (minDiameter + maxDiameter) / 2;
    final t = ((value - minValue) / (maxValue - minValue))
        .clamp(0, 1)
        .toDouble();
    return minDiameter + (maxDiameter - minDiameter) * t;
  }

  @override
  bool operator ==(Object other) =>
      other is MarkerScale &&
      other.minValue == minValue &&
      other.maxValue == maxValue &&
      other.minDiameter == minDiameter &&
      other.maxDiameter == maxDiameter;

  @override
  int get hashCode => Object.hash(minValue, maxValue, minDiameter, maxDiameter);
}

/// Styling for map markers.
class MarkerStyle {
  /// Creates marker styling.
  const MarkerStyle({
    this.fillColor = const Color(0xFFC04F00),
    this.borderColor = const Color(0xFFF3FBFE),
    this.borderWidth = 2,
    this.textColor = const Color(0xFFFFFFFF),
    this.textStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    this.scale = const MarkerScale(),
  });

  /// Marker fill color.
  final Color fillColor;

  /// Marker border color.
  final Color borderColor;

  /// Marker border width in view-box units.
  final double borderWidth;

  /// Marker text color.
  final Color textColor;

  /// Marker text style.
  final TextStyle textStyle;

  /// Value-to-diameter scale.
  final MarkerScale scale;

  @override
  bool operator ==(Object other) =>
      other is MarkerStyle &&
      other.fillColor == fillColor &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.textColor == textColor &&
      other.textStyle == textStyle &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    fillColor,
    borderColor,
    borderWidth,
    textColor,
    textStyle,
    scale,
  );
}

/// Styling for default and custom tooltips.
class TooltipStyle {
  /// Creates tooltip styling.
  const TooltipStyle({
    this.backgroundColor = const Color(0xFF2C3134),
    this.textColor = const Color(0xFFEBF2F5),
    this.borderRadius = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    this.textStyle = const TextStyle(fontSize: 12),
  });

  /// Tooltip background color.
  final Color backgroundColor;

  /// Tooltip text color.
  final Color textColor;

  /// Tooltip corner radius.
  final double borderRadius;

  /// Tooltip content padding.
  final EdgeInsets padding;

  /// Tooltip text style.
  final TextStyle textStyle;

  @override
  bool operator ==(Object other) =>
      other is TooltipStyle &&
      other.backgroundColor == backgroundColor &&
      other.textColor == textColor &&
      other.borderRadius == borderRadius &&
      other.padding == padding &&
      other.textStyle == textStyle;

  @override
  int get hashCode =>
      Object.hash(backgroundColor, textColor, borderRadius, padding, textStyle);
}

/// Visual configuration for [ShapeMap].
class ShapeMapStyle {
  /// Creates map styling.
  const ShapeMapStyle({
    this.dataColor = const Color(0xFFFFDBC9),
    this.emptyColor = const Color(0xFFE2E9ED),
    this.borderColor = const Color(0xFFF3FBFE),
    this.borderWidth = 2,
    this.hoverColor,
    this.selectedColor,
    this.selectedBorderColor,
    this.selectedBorderWidth = 0,
    this.selectedOpacity = 70 / 255,
    this.marker = const MarkerStyle(),
    this.tooltip = const TooltipStyle(),
  });

  /// Fill used for regions with data and no explicit fill.
  final Color dataColor;

  /// Fill used for regions without data.
  final Color emptyColor;

  /// Internal border color.
  final Color borderColor;

  /// Border width in logical view-box units before internal clipping.
  final double borderWidth;

  /// Optional hover highlight color.
  final Color? hoverColor;

  /// Optional selected highlight color.
  final Color? selectedColor;

  /// Optional border color for the selected region.
  final Color? selectedBorderColor;

  /// Selected-region border width in screen pixels.
  final double selectedBorderWidth;

  /// Opacity of the selected-region fill.
  final double selectedOpacity;

  /// Marker configuration.
  final MarkerStyle marker;

  /// Tooltip configuration.
  final TooltipStyle tooltip;

  @override
  bool operator ==(Object other) =>
      other is ShapeMapStyle &&
      other.dataColor == dataColor &&
      other.emptyColor == emptyColor &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.hoverColor == hoverColor &&
      other.selectedColor == selectedColor &&
      other.selectedBorderColor == selectedBorderColor &&
      other.selectedBorderWidth == selectedBorderWidth &&
      other.selectedOpacity == selectedOpacity &&
      other.marker == marker &&
      other.tooltip == tooltip;

  @override
  int get hashCode => Object.hash(
    dataColor,
    emptyColor,
    borderColor,
    borderWidth,
    hoverColor,
    selectedColor,
    selectedBorderColor,
    selectedBorderWidth,
    selectedOpacity,
    marker,
    tooltip,
  );
}
