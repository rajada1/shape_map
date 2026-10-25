import 'dart:ui';

import 'package:shape_map/shape_map.dart';

/// Data and marker fixtures matching mapa_view_1.svg.
class ReferenceLayouts {
  ReferenceLayouts._();

  /// South American country data shown in the reference layout.
  static const southAmericaData = <String, MapRegionData>{
    'BR': MapRegionData(value: 9800),
    'AR': MapRegionData(value: 820),
    'PE': MapRegionData(value: 610),
    'CL': MapRegionData(value: 450),
    'BO': MapRegionData(value: 290),
    'PY': MapRegionData(value: 180),
    'EC': MapRegionData(value: 150),
    'UY': MapRegionData(value: 90),
  };

  /// South American markers with the exact reference centers and diameters.
  static const southAmericaMarkers = <MapMarkerData>[
    MapMarkerData(
      regionId: 'BR',
      value: 9800,
      label: '9,8 mil',
      diameter: 66,
      position: Offset(215, 125),
    ),
    MapMarkerData(
      regionId: 'AR',
      value: 820,
      label: '820',
      diameter: 38,
      position: Offset(142, 268),
    ),
    MapMarkerData(
      regionId: 'PE',
      value: 610,
      label: '610',
      diameter: 36,
      position: Offset(92, 112),
    ),
    MapMarkerData(
      regionId: 'CL',
      value: 450,
      label: '450',
      diameter: 34,
      position: Offset(88, 240),
    ),
    MapMarkerData(
      regionId: 'BO',
      value: 290,
      label: '290',
      diameter: 32,
      position: Offset(140, 150),
    ),
    MapMarkerData(
      regionId: 'PY',
      value: 180,
      label: '180',
      diameter: 32,
      position: Offset(172, 186),
    ),
    MapMarkerData(
      regionId: 'EC',
      value: 150,
      label: '150',
      diameter: 30,
      position: Offset(64, 72),
    ),
    MapMarkerData(
      regionId: 'UY',
      value: 90,
      label: '90',
      diameter: 30,
      position: Offset(188, 236),
    ),
  ];

  /// All Brazilian federative units have data in the reference layout.
  static Map<String, MapRegionData> brazilData({int bahiaValue = 620}) {
    return {
      for (final region in ShapeMaps.brazilStates.regions)
        region.id: MapRegionData(
          value: region.id == 'BR-BA' ? bahiaValue : 1,
          label: region.id == 'BR-BA' ? 'Bahia' : null,
        ),
    };
  }

  /// Brazilian markers mapped to the 25 reference SVG badges.
  static const brazilMarkers = <MapMarkerData>[
    MapMarkerData(regionId: 'BR-AP', value: 1, diameter: 9.5, showLabel: false),
    MapMarkerData(regionId: 'BR-AC', value: 1, diameter: 9.5, showLabel: false),
    MapMarkerData(regionId: 'BR-RR', value: 1, diameter: 9.5, showLabel: false),
    MapMarkerData(
      regionId: 'BR-SE',
      value: 1,
      diameter: 10.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-TO',
      value: 1,
      diameter: 11.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-AL',
      value: 1,
      diameter: 11.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-RN',
      value: 1,
      diameter: 12.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-RO',
      value: 1,
      diameter: 12.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-PI',
      value: 1,
      diameter: 12.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-PB',
      value: 1,
      diameter: 12.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-MA',
      value: 1,
      diameter: 13.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-MS',
      value: 1,
      diameter: 15.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-MT',
      value: 1,
      diameter: 16.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-ES',
      value: 1,
      diameter: 16.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-DF',
      value: 1,
      diameter: 17.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-CE',
      value: 1,
      diameter: 17.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-PA',
      value: 1,
      diameter: 18.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-GO',
      value: 1,
      diameter: 18.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-PE',
      value: 1,
      diameter: 20.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-SC',
      value: 1,
      diameter: 21.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-BA',
      value: 1,
      diameter: 23.5,
      showLabel: false,
    ),
    MapMarkerData(
      regionId: 'BR-RS',
      value: 1,
      diameter: 23.5,
      showLabel: false,
    ),
    MapMarkerData(regionId: 'BR-RJ', value: 1, diameter: 24.5, label: '770'),
    MapMarkerData(regionId: 'BR-MG', value: 1, diameter: 26.5, label: '980'),
    MapMarkerData(regionId: 'BR-PR', value: 1, diameter: 27.5, label: '910'),
    MapMarkerData(
      regionId: 'BR-SP',
      value: 1,
      diameter: 48.5,
      label: '2,3 mil',
    ),
  ];
}
