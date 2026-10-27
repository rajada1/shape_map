import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

const _southData = <String, MapRegionData>{
  'BR': MapRegionData(value: 9800),
  'AR': MapRegionData(value: 820),
  'PE': MapRegionData(value: 610),
  'CL': MapRegionData(value: 450),
  'BO': MapRegionData(value: 290),
  'PY': MapRegionData(value: 180),
  'EC': MapRegionData(value: 150),
  'UY': MapRegionData(value: 90),
};

const _southMarkers = <MapMarkerData>[
  MapMarkerData(regionId: 'BR', value: 9800, label: '9,8 mil', diameter: 66),
  MapMarkerData(regionId: 'AR', value: 820, label: '820', diameter: 38),
  MapMarkerData(regionId: 'PE', value: 610, label: '610', diameter: 36),
  MapMarkerData(regionId: 'CL', value: 450, label: '450', diameter: 34),
  MapMarkerData(regionId: 'BO', value: 290, label: '290', diameter: 32),
  MapMarkerData(regionId: 'PY', value: 180, label: '180', diameter: 32),
  MapMarkerData(regionId: 'EC', value: 150, label: '150', diameter: 30),
  MapMarkerData(regionId: 'UY', value: 90, label: '90', diameter: 30),
];

const _brazilMarkers = <MapMarkerData>[
  MapMarkerData(regionId: 'BR-AP', value: 1, diameter: 9.5, showLabel: false),
  MapMarkerData(regionId: 'BR-AC', value: 1, diameter: 9.5, showLabel: false),
  MapMarkerData(regionId: 'BR-RR', value: 1, diameter: 9.5, showLabel: false),
  MapMarkerData(regionId: 'BR-SE', value: 1, diameter: 10.5, showLabel: false),
  MapMarkerData(regionId: 'BR-TO', value: 1, diameter: 11.5, showLabel: false),
  MapMarkerData(regionId: 'BR-AL', value: 1, diameter: 11.5, showLabel: false),
  MapMarkerData(regionId: 'BR-RN', value: 1, diameter: 12.5, showLabel: false),
  MapMarkerData(regionId: 'BR-RO', value: 1, diameter: 12.5, showLabel: false),
  MapMarkerData(regionId: 'BR-PI', value: 1, diameter: 12.5, showLabel: false),
  MapMarkerData(regionId: 'BR-PB', value: 1, diameter: 12.5, showLabel: false),
  MapMarkerData(regionId: 'BR-MA', value: 1, diameter: 13.5, showLabel: false),
  MapMarkerData(regionId: 'BR-MS', value: 1, diameter: 15.5, showLabel: false),
  MapMarkerData(regionId: 'BR-MT', value: 1, diameter: 16.5, showLabel: false),
  MapMarkerData(regionId: 'BR-ES', value: 1, diameter: 16.5, showLabel: false),
  MapMarkerData(regionId: 'BR-DF', value: 1, diameter: 17.5, showLabel: false),
  MapMarkerData(regionId: 'BR-CE', value: 1, diameter: 17.5, showLabel: false),
  MapMarkerData(regionId: 'BR-PA', value: 1, diameter: 18.5, showLabel: false),
  MapMarkerData(regionId: 'BR-GO', value: 1, diameter: 18.5, showLabel: false),
  MapMarkerData(regionId: 'BR-PE', value: 1, diameter: 20.5, showLabel: false),
  MapMarkerData(regionId: 'BR-SC', value: 1, diameter: 21.5, showLabel: false),
  MapMarkerData(regionId: 'BR-BA', value: 1, diameter: 23.5, showLabel: false),
  MapMarkerData(regionId: 'BR-RS', value: 1, diameter: 23.5, showLabel: false),
  MapMarkerData(regionId: 'BR-RJ', value: 1, diameter: 24.5, label: '770'),
  MapMarkerData(regionId: 'BR-MG', value: 1, diameter: 26.5, label: '980'),
  MapMarkerData(regionId: 'BR-PR', value: 1, diameter: 27.5, label: '910'),
  MapMarkerData(regionId: 'BR-SP', value: 1, diameter: 48.5, label: '2,3 mil'),
];

Map<String, MapRegionData> _brazilData() => {
  for (final region in ShapeMaps.brazilStates.regions)
    region.id: MapRegionData(
      value: region.id == 'BR-BA' ? 620 : 1,
      label: region.id == 'BR-BA' ? 'Bahia' : null,
    ),
};

const _latinData = <String, MapRegionData>{
  'BR': MapRegionData(value: 9800),
  'MX': MapRegionData(value: 7400),
  'AR': MapRegionData(value: 820),
  'CO': MapRegionData(value: 760),
  'CL': MapRegionData(value: 450),
  'PE': MapRegionData(value: 610),
  'CU': MapRegionData(value: 210),
  'GT': MapRegionData(value: 180),
};

const _latinMarkers = <MapMarkerData>[
  MapMarkerData(regionId: 'BR', value: 1, label: '9,8 mil', diameter: 60),
  MapMarkerData(regionId: 'MX', value: 1, label: '7,4 mil', diameter: 54),
  MapMarkerData(regionId: 'AR', value: 1, label: '820', diameter: 36),
  MapMarkerData(regionId: 'CO', value: 1, label: '760', diameter: 34),
  MapMarkerData(regionId: 'PE', value: 1, label: '610', diameter: 32),
  MapMarkerData(regionId: 'CL', value: 1, label: '450', diameter: 30),
];

const _worldData = <String, MapRegionData>{
  'BR': MapRegionData(value: 9800),
  'US': MapRegionData(value: 8700),
  'CN': MapRegionData(value: 7600),
  'IN': MapRegionData(value: 5100),
  'DE': MapRegionData(value: 2300),
  'NG': MapRegionData(value: 1200),
  'AU': MapRegionData(value: 900),
};

const _worldMarkers = <MapMarkerData>[
  MapMarkerData(regionId: 'BR', value: 1, label: '9,8 mil', diameter: 44),
  MapMarkerData(regionId: 'US', value: 1, label: '8,7 mil', diameter: 42),
  MapMarkerData(regionId: 'CN', value: 1, label: '7,6 mil', diameter: 40),
  MapMarkerData(regionId: 'IN', value: 1, label: '5,1 mil', diameter: 34),
  MapMarkerData(regionId: 'AU', value: 1, label: '900', diameter: 26),
];

void _setGoldenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _map(
  MapDefinition definition,
  Map<String, MapRegionData> data,
  List<MapMarkerData> markers,
) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: definition.viewBox.width,
      height: definition.viewBox.height,
      child: ShapeMap(
        map: definition,
        data: data,
        markers: markers,
        animationDuration: Duration.zero,
      ),
    ),
  ),
);

void main() {
  testWidgets('South America layout', (tester) async {
    _setGoldenSize(tester, const Size(820, 1040));
    await tester.pumpWidget(
      _map(ShapeMaps.southAmerica, _southData, _southMarkers),
    );
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/south_america.png'),
    );
  });

  testWidgets('Brazil states layout', (tester) async {
    _setGoldenSize(tester, const Size(900, 1000));
    final controller = ShapeMapController()..select('BR-BA');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 900,
            height: 1000,
            child: ShapeMap(
              map: ShapeMaps.brazilStates,
              data: _brazilData(),
              markers: _brazilMarkers,
              controller: controller,
              animationDuration: Duration.zero,
              style: const ShapeMapStyle(
                marker: MarkerStyle(
                  borderWidth: 1.5,
                  textStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/brazil_states.png'),
    );
    controller.dispose();
  });

  testWidgets('World layout', (tester) async {
    _setGoldenSize(tester, const Size(1200, 620));
    await tester.pumpWidget(_map(ShapeMaps.world, _worldData, _worldMarkers));
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/world.png'),
    );
  });

  testWidgets('Latin America layout', (tester) async {
    _setGoldenSize(tester, const Size(1100, 780));
    await tester.pumpWidget(
      _map(ShapeMaps.latinAmerica, _latinData, _latinMarkers),
    );
    await tester.pump();
    await expectLater(
      find.byType(ShapeMap),
      matchesGoldenFile('goldens/latin_america.png'),
    );
  });
}
