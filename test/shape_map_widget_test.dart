import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/transform.dart';

void main() {
  testWidgets('renders countries, selects Brazil and shows tooltip', (
    tester,
  ) async {
    MapRegion? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 400,
            child: ShapeMap(
              map: ShapeMaps.southAmericaCountries,
              data: const {'BR': MapRegionData(value: 620)},
              animationDuration: Duration.zero,
              onRegionTap: (region) => tapped = region,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(4));
    final mapFinder = find.byType(ShapeMap);
    final transform = calculateTransform(
      ShapeMaps.southAmericaCountries,
      tester.getSize(mapFinder),
      BoxFit.contain,
      Alignment.center,
    );
    final brazilAnchor = ShapeMaps.southAmericaCountries
        .regionById('BR')!
        .markerAnchor;
    final tapPosition =
        tester.getTopLeft(mapFinder) + transform.forward(brazilAnchor);
    await tester.tapAt(tapPosition);
    await tester.pump();
    expect(tapped?.id, 'BR');
    expect(find.text('Brasil: 620'), findsOneWidget);
  });

  testWidgets('renders Brazilian states and animates data changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 330,
            child: ShapeMap(
              map: ShapeMaps.brazilStates,
              animationDuration: const Duration(milliseconds: 300),
              data: const {'BR-BA': MapRegionData(value: 620, label: 'Bahia')},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ShapeMap), findsOneWidget);
  });
}
