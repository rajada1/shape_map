import 'package:flutter/foundation.dart';

/// Read-only controller state consumed by render layers.
abstract interface class ShapeMapControllerLike {
  /// Selected region id.
  String? get selectedRegionId;

  /// Hovered region id.
  String? get hoveredRegionId;
}

/// Controls selected and hovered regions of a [ShapeMap].
class ShapeMapController extends ChangeNotifier
    implements ShapeMapControllerLike {
  String? _selectedRegionId;
  String? _hoveredRegionId;

  /// The currently selected region, if any.
  @override
  String? get selectedRegionId => _selectedRegionId;

  /// The currently hovered region, if any.
  @override
  String? get hoveredRegionId => _hoveredRegionId;

  /// Selects [regionId], or clears selection when it is null.
  void select(String? regionId) {
    if (_selectedRegionId == regionId) return;
    _selectedRegionId = regionId;
    notifyListeners();
  }

  /// Updates the hovered region.
  void setHovered(String? regionId) {
    if (_hoveredRegionId == regionId) return;
    _hoveredRegionId = regionId;
    notifyListeners();
  }

  /// Clears the current selection.
  void clearSelection() => select(null);
}
