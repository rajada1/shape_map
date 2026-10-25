import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/transform.dart';

const _data = <String, MapRegionData>{
  'BR': MapRegionData(value: 620, label: 'Brasil'),
};

Widget _map({
  required Animation<double> animation,
  ShapeMapEntrance? entrance,
  ShapeMapController? controller,
}) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 342,
      height: 400,
      child: ShapeMap(
        map: ShapeMaps.southAmericaCountries,
        data: _data,
        controller: controller,
        entrance: entrance ?? const ShapeMapEntrance(),
        entranceAnimation: animation,
      ),
    ),
  ),
);

void main() {
  test('entrance configurations compare by content', () {
    expect(
      const ShapeMapEntrance(style: ShapeMapEntranceStyle.draw),
      const ShapeMapEntrance(style: ShapeMapEntranceStyle.draw),
    );
    expect(
      const ShapeMapEntrance(style: ShapeMapEntranceStyle.draw),
      isNot(const ShapeMapEntrance(style: ShapeMapEntranceStyle.grow)),
    );
  });

  testWidgets('external progress blocks interaction until completion', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
      value: 0.5,
    );
    final controller = ShapeMapController();
    MapRegion? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 400,
            child: ShapeMap(
              map: ShapeMaps.southAmericaCountries,
              data: _data,
              controller: controller,
              entrance: const ShapeMapEntrance(
                style: ShapeMapEntranceStyle.fade,
              ),
              entranceAnimation: animation,
              onRegionTap: (region) => tapped = region,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final map = find.byType(ShapeMap);
    await tester.tapAt(tester.getCenter(map));
    expect(tapped, isNull);
    animation.value = 1;
    await tester.pump();
    final transform = calculateTransform(
      ShapeMaps.southAmericaCountries,
      tester.getSize(map),
      BoxFit.contain,
      Alignment.center,
    );
    await tester.tapAt(
      tester.getTopLeft(map) +
          transform.forward(
            ShapeMaps.southAmericaCountries.regionById('BR')!.markerAnchor,
          ),
    );
    expect(tapped?.id, 'BR');
    animation.dispose();
    controller.dispose();
  });

  testWidgets('internal entrance completes and then shows tooltip', (
    tester,
  ) async {
    final controller = ShapeMapController()..select('BR');
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 342,
            height: 400,
            child: ShapeMap(
              map: ShapeMaps.southAmericaCountries,
              data: _data,
              controller: controller,
              entrance: const ShapeMapEntrance(
                duration: Duration(milliseconds: 100),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('shape-map-tooltip')),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('shape-map-tooltip')),
      findsOneWidget,
    );
    controller.dispose();
  });

  testWidgets(
    'disableAnimations completes without changing external animation',
    (tester) async {
      final animation = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
        value: 0,
      );
      final controller = ShapeMapController()..select('BR');
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _map(animation: animation, controller: controller),
        ),
      );
      await tester.pump();
      expect(animation.value, 0);
      expect(
        find.byKey(const ValueKey<String>('shape-map-tooltip')),
        findsOneWidget,
      );
      animation.dispose();
      controller.dispose();
    },
  );

  testWidgets('changing the map restarts an internal entrance', (tester) async {
    final entrance = ShapeMapEntrance(
      duration: const Duration(milliseconds: 500),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 342,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmericaCountries,
            entrance: entrance,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 342,
          height: 330,
          child: ShapeMap(map: ShapeMaps.brazilStates, entrance: entrance),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
  });

  test('top-to-bottom stagger starts with the smallest transformed y', () {
    final cache = MapRenderCache();
    cache.update(
      ShapeMaps.southAmericaCountries,
      const Size(342, 400),
      BoxFit.contain,
      Alignment.center,
    );
    cache.updateStagger(ShapeMapStaggerOrder.topToBottom);
    final first = cache.centers
        .asMap()
        .entries
        .reduce((a, b) => a.value.dy <= b.value.dy ? a : b)
        .key;
    expect(cache.staggerStart(first), 0);
    cache.dispose();
  });
}
