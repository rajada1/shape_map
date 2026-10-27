import 'package:shape_map/shape_map.dart';

/// Data and markers using anchors computed from public map geometry.
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

  /// South American markers anchored by each region's polylabel position.
  static const southAmericaMarkers = <MapMarkerData>[
    MapMarkerData(regionId: 'BR', value: 9800, label: '9,8 mil', diameter: 66),
    MapMarkerData(regionId: 'AR', value: 820, label: '820', diameter: 38),
    MapMarkerData(regionId: 'PE', value: 610, label: '610', diameter: 36),
    MapMarkerData(regionId: 'CL', value: 450, label: '450', diameter: 34),
    MapMarkerData(regionId: 'BO', value: 290, label: '290', diameter: 32),
    MapMarkerData(regionId: 'PY', value: 180, label: '180', diameter: 32),
    MapMarkerData(regionId: 'EC', value: 150, label: '150', diameter: 30),
    MapMarkerData(regionId: 'UY', value: 90, label: '90', diameter: 30),
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

  /// Latin American sample data (largest economies of the region).
  static const latinAmericaData = <String, MapRegionData>{
    'BR': MapRegionData(value: 9800),
    'MX': MapRegionData(value: 7400),
    'AR': MapRegionData(value: 820),
    'CO': MapRegionData(value: 760),
    'CL': MapRegionData(value: 450),
    'PE': MapRegionData(value: 610),
    'CU': MapRegionData(value: 210),
    'GT': MapRegionData(value: 180),
  };

  /// Markers for [latinAmericaData].
  static const latinAmericaMarkers = <MapMarkerData>[
    MapMarkerData(regionId: 'BR', value: 9800, label: '9,8 mil', diameter: 60),
    MapMarkerData(regionId: 'MX', value: 7400, label: '7,4 mil', diameter: 54),
    MapMarkerData(regionId: 'AR', value: 820, label: '820', diameter: 36),
    MapMarkerData(regionId: 'CO', value: 760, label: '760', diameter: 34),
    MapMarkerData(regionId: 'PE', value: 610, label: '610', diameter: 32),
    MapMarkerData(regionId: 'CL', value: 450, label: '450', diameter: 30),
  ];

  /// World sample data, one highlighted country per continent.
  static const worldData = <String, MapRegionData>{
    'BR': MapRegionData(value: 9800),
    'US': MapRegionData(value: 8700),
    'CN': MapRegionData(value: 7600),
    'IN': MapRegionData(value: 5100),
    'DE': MapRegionData(value: 2300),
    'NG': MapRegionData(value: 1200),
    'AU': MapRegionData(value: 900),
  };

  /// Markers for [worldData].
  static const worldMarkers = <MapMarkerData>[
    MapMarkerData(regionId: 'BR', value: 9800, label: '9,8 mil', diameter: 44),
    MapMarkerData(regionId: 'US', value: 8700, label: '8,7 mil', diameter: 42),
    MapMarkerData(regionId: 'CN', value: 7600, label: '7,6 mil', diameter: 40),
    MapMarkerData(regionId: 'IN', value: 5100, label: '5,1 mil', diameter: 34),
    MapMarkerData(regionId: 'AU', value: 900, label: '900', diameter: 26),
  ];

  /// Brazilian markers scaled over the 27 computed UF anchors.
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
