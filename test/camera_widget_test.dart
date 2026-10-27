import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/markers.dart';
import 'package:shape_map/src/rendering/painters.dart';
import 'package:shape_map/src/rendering/transform.dart';
import 'package:shape_map/src/state/camera.dart';

void main() {
  testWidgets('instant zoom refreshes the selected tooltip position', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    final selection = ShapeMapController()..select('BR');
    addTearDown(camera.dispose);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _mapApp(
        camera: camera,
        controller: selection,
        data: const {'BR': MapRegionData(value: 10)},
      ),
    );
    await tester.pump();

    camera.zoomTo(2, focal: const Offset(170, 200), duration: Duration.zero);
    await tester.pump();

    final mapFinder = find.byType(ShapeMap);
    final tooltip = find.byKey(const ValueKey('shape-map-tooltip'));
    final mapSize = tester.getSize(mapFinder);
    final transform = calculateTransform(
      ShapeMaps.southAmerica,
      mapSize,
      BoxFit.contain,
      Alignment.center,
    );
    final anchor = ShapeMaps.southAmerica.regionById('BR')!.markerAnchor;
    final position = camera.pan + transform.forward(anchor) * camera.scale;
    final tooltipSize = tester.getSize(tooltip);
    final desired =
        position + const Offset(8, -8) - Offset(0, tooltipSize.height);
    final expected = Offset(
      desired.dx.clamp(0, mapSize.width - tooltipSize.width).toDouble(),
      desired.dy.clamp(0, mapSize.height - tooltipSize.height).toDouble(),
    );
    expect(tester.getTopLeft(tooltip) - tester.getTopLeft(mapFinder), expected);
  });

  testWidgets('resize stores the camera without notifying during build', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    final key = GlobalKey<_ResizeHarnessState>();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _ResizeHarness(key: key, camera: camera),
      ),
    );
    await tester.pump();
    camera.zoomTo(4, focal: const Offset(150, 120), duration: Duration.zero);
    await tester.pump();
    final before = _inverseForTest(
      camera,
      tester.getSize(find.byType(ShapeMap)),
      const Offset(150, 120),
    );
    key.currentState!.resizeTo(420);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final afterSize = tester.getSize(find.byType(ShapeMap));
    final after = _inverseForTest(
      camera,
      afterSize,
      Offset(afterSize.width / 2, afterSize.height / 2),
    );
    expect(after.dx, closeTo(before.dx, 0.001));
    expect(after.dy, closeTo(before.dy, 0.001));
  });

  testWidgets(
    'zoom disabled leaves camera unchanged and taps select immediately',
    (tester) async {
      final camera = ShapeMapCameraController();
      MapRegion? selected;
      addTearDown(camera.dispose);
      await tester.pumpWidget(
        _mapApp(
          camera: camera,
          onRegionSelected: (region) => selected = region,
        ),
      );
      await tester.pump();
      final map = find.byType(ShapeMap);
      final point = _anchorPoint(tester, ShapeMaps.southAmerica, 'BR', camera);
      final oldScale = camera.scale;
      final oldPan = camera.pan;

      await tester.drag(map, const Offset(80, 20));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getTopLeft(map) + const Offset(170, 200),
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.tapAt(tester.getTopLeft(map) + point);
      await tester.pump();

      expect(camera.scale, oldScale);
      expect(camera.pan, oldPan);
      expect(selected?.id, 'BR');
    },
  );

  testWidgets(
    'tap selects once, repeated selection is stable, background clears',
    (tester) async {
      final camera = ShapeMapCameraController();
      final selected = <String?>[];
      addTearDown(camera.dispose);
      await tester.pumpWidget(
        _mapApp(
          camera: camera,
          zoomEnabled: true,
          onRegionSelected: (region) => selected.add(region?.id),
        ),
      );
      await tester.pump();
      final map = find.byType(ShapeMap);
      final br =
          tester.getTopLeft(map) +
          _anchorPoint(tester, ShapeMaps.southAmerica, 'BR', camera);
      await tester.tapAt(br);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tapAt(br);
      await tester.pump(const Duration(milliseconds: 350));

      expect(selected, ['BR']);
      await tester.tapAt(tester.getTopLeft(map));
      await tester.pump(const Duration(milliseconds: 350));
      expect(selected, ['BR', null]);
    },
  );

  testWidgets('one-finger drag pans at zoom and does not select', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    MapRegion? selected;
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      _mapApp(
        camera: camera,
        zoomEnabled: true,
        onRegionSelected: (region) => selected = region,
      ),
    );
    await tester.pump();
    camera.zoomTo(2, duration: Duration.zero);
    await tester.pump();
    final map = find.byType(ShapeMap);
    final oldPan = camera.pan;
    await tester.drag(map, const Offset(40, 15));
    await tester.pump(const Duration(milliseconds: 100));

    expect(camera.pan, isNot(oldPan));
    expect(selected, isNull);
  });

  testWidgets('pinch increases scale and respects maxScale', (tester) async {
    final camera = ShapeMapCameraController();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      _mapApp(camera: camera, zoomEnabled: true, maxScale: 2),
    );
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(ShapeMap));
    final first = await tester.createGesture(
      pointer: 1,
      kind: PointerDeviceKind.touch,
    );
    final second = await tester.createGesture(
      pointer: 2,
      kind: PointerDeviceKind.touch,
    );
    await first.down(origin + const Offset(130, 190));
    await second.down(origin + const Offset(210, 190));
    await tester.pump();
    await first.moveTo(origin + const Offset(90, 190));
    await second.moveTo(origin + const Offset(250, 190));
    await tester.pump();
    await first.moveTo(origin + const Offset(20, 190));
    await second.moveTo(origin + const Offset(320, 190));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 60));

    expect(camera.scale, greaterThan(1));
    expect(camera.scale, lessThanOrEqualTo(2));
  });

  testWidgets('mouse scroll zooms around the pointer', (tester) async {
    final camera = ShapeMapCameraController();
    addTearDown(camera.dispose);
    await tester.pumpWidget(_mapApp(camera: camera, zoomEnabled: true));
    await tester.pump();
    final map = find.byType(ShapeMap);
    final localFocal = const Offset(240, 180);
    final viewBoxPoint = _viewBoxPoint(tester, localFocal, camera);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getTopLeft(map) + localFocal,
        scrollDelta: const Offset(0, -40),
      ),
    );
    await tester.pump();

    final transform = calculateTransform(
      ShapeMaps.southAmerica,
      tester.getSize(map),
      BoxFit.contain,
      Alignment.center,
    );
    final transformed =
        camera.pan + transform.forward(viewBoxPoint) * camera.scale;
    expect(transformed.dx, closeTo(localFocal.dx, 0.01));
    expect(transformed.dy, closeTo(localFocal.dy, 0.01));
  });

  testWidgets('double tap zooms in and toggles back at maxScale', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      _mapApp(
        camera: camera,
        zoomEnabled: true,
        maxScale: 2,
        cameraAnimationDuration: Duration.zero,
      ),
    );
    await tester.pump();
    final map = find.byType(ShapeMap);
    final point = tester.getTopLeft(map) + const Offset(170, 200);
    await _doubleTap(tester, point);
    expect(camera.scale, 2);
    await _doubleTap(tester, point);
    expect(camera.scale, 1);
  });

  test('marker diameter stays in pixels while camera zooms', () {
    final map = MapDefinition(
      id: 'marker-test',
      viewBox: const Size(100, 100),
      regions: [
        MapRegion(
          id: 'R',
          name: 'Region',
          geometry: MapGeometry([
            const MapPathCommand.move(10, 10),
            const MapPathCommand.line(90, 10),
            const MapPathCommand.line(90, 90),
            const MapPathCommand.line(10, 90),
            const MapPathCommand.close(),
          ]),
          markerAnchor: const Offset(50, 50),
        ),
      ],
    );
    final cache = MapRenderCache()
      ..update(map, const Size(200, 200), BoxFit.contain, Alignment.center);
    final layout = MarkerLayoutCache()
      ..update(
        map,
        const [
          MapMarkerData(
            regionId: 'R',
            value: 1,
            diameter: 10,
            showLabel: false,
          ),
        ],
        const MarkerStyle(),
        const {},
      );
    final camera = ShapeMapCameraController();
    final animation = const AlwaysStoppedAnimation<double>(1);
    final painter = MarkerPainter(
      cache: cache,
      layoutCache: layout,
      style: const MarkerStyle(),
      animation: animation,
      progress: animation,
      entrance: null,
      repaint: animation,
      camera: camera,
    );
    final firstCanvas = TestRecordingCanvas();
    painter.paint(firstCanvas, const Size(200, 200));
    camera.updateFromHost(3, const Offset(-200, -200));
    final secondCanvas = TestRecordingCanvas();
    painter.paint(secondCanvas, const Size(200, 200));

    double radius(TestRecordingCanvas canvas) =>
        canvas.invocations
                .where((entry) => entry.invocation.memberName == #drawCircle)
                .first
                .invocation
                .positionalArguments[1]
            as double;
    expect(radius(secondCanvas), radius(firstCanvas));
    layout.dispose();
    cache.dispose();
    camera.dispose();
  });

  test('screen-pixel marker diameter and shadow are camera invariant', () {
    final map = MapDefinition(
      id: 'marker-screen-pixels',
      viewBox: const Size(100, 100),
      regions: [
        MapRegion(
          id: 'R',
          name: 'Region',
          geometry: MapGeometry([
            const MapPathCommand.move(10, 10),
            const MapPathCommand.line(90, 10),
            const MapPathCommand.line(90, 90),
            const MapPathCommand.line(10, 90),
            const MapPathCommand.close(),
          ]),
          markerAnchor: const Offset(50, 50),
        ),
      ],
    );
    final cache = MapRenderCache()
      ..update(map, const Size(200, 200), BoxFit.contain, Alignment.center);
    final layout = MarkerLayoutCache()
      ..update(
        map,
        const [
          MapMarkerData(
            regionId: 'R',
            value: 1,
            diameter: 10,
            diameterUnit: MarkerDiameterUnit.screenPixels,
            showLabel: false,
          ),
        ],
        const MarkerStyle(
          shadow: MarkerShadow(
            color: Color(0x55000000),
            blurRadius: 2,
            offset: Offset(1, 2),
          ),
        ),
        const {},
      );
    final camera = ShapeMapCameraController();
    final animation = const AlwaysStoppedAnimation<double>(1);
    final painter = MarkerPainter(
      cache: cache,
      layoutCache: layout,
      style: const MarkerStyle(
        shadow: MarkerShadow(
          color: Color(0x55000000),
          blurRadius: 2,
          offset: Offset(1, 2),
        ),
      ),
      animation: animation,
      progress: animation,
      entrance: null,
      repaint: animation,
      camera: camera,
    );
    final firstCanvas = TestRecordingCanvas();
    painter.paint(firstCanvas, const Size(200, 200));
    camera.updateFromHost(3, const Offset(-200, -200));
    final secondCanvas = TestRecordingCanvas();
    painter.paint(secondCanvas, const Size(200, 200));

    double radius(TestRecordingCanvas canvas) =>
        canvas.invocations
                .where((entry) => entry.invocation.memberName == #drawCircle)
                .elementAt(1)
                .invocation
                .positionalArguments[1]
            as double;
    expect(radius(secondCanvas), radius(firstCanvas));
    expect(
      firstCanvas.invocations.where(
        (entry) => entry.invocation.memberName == #drawCircle,
      ),
      hasLength(3),
    );
    layout.dispose();
    cache.dispose();
    camera.dispose();
  });
  testWidgets('trackpad pan-zoom updates scale and pan', (tester) async {
    final camera = ShapeMapCameraController();
    addTearDown(camera.dispose);
    await tester.pumpWidget(_mapApp(camera: camera, zoomEnabled: true));
    await tester.pump();
    final map = find.byType(ShapeMap);
    final position = tester.getTopLeft(map) + const Offset(170, 200);
    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(position));
    await tester.pump();
    await tester.sendEventToBinding(
      pointer.panZoomUpdate(position, pan: const Offset(30, 20), scale: 1.5),
    );
    await tester.pump();
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump(const Duration(milliseconds: 60));

    expect(camera.scale, greaterThan(1));
    expect(camera.pan, isNot(Offset.zero));
  });

  testWidgets('camera animations hide the tooltip until they settle', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    final selection = ShapeMapController()..select('BR');
    addTearDown(camera.dispose);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _mapApp(
        camera: camera,
        controller: selection,
        cameraAnimationDuration: const Duration(milliseconds: 300),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-map-tooltip')), findsOneWidget);
    camera.zoomTo(2);
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-map-tooltip')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shape-map-tooltip')), findsOneWidget);
  });

  testWidgets('map changes reset the camera while the same map preserves it', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    final key = GlobalKey<_MapSwitcherState>();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _MapSwitcher(key: key, camera: camera),
      ),
    );
    await tester.pump();
    camera.zoomTo(2, duration: Duration.zero);
    await tester.pump();
    key.currentState!.rebuildSameMap();
    await tester.pump();
    expect(camera.scale, 2);
    key.currentState!.switchMap();
    await tester.pump();
    expect(camera.scale, 1);
    expect(camera.pan, Offset.zero);
  });

  testWidgets('external camera remains usable after unmount', (tester) async {
    final camera = ShapeMapCameraController();
    final key = GlobalKey<_ToggleMapState>();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _ToggleMap(key: key, camera: camera),
      ),
    );
    await tester.pump();
    key.currentState!.hide();
    await tester.pump();
    expect(() => camera.zoomTo(2), returnsNormally);
    expect(camera.scale, 1);
  });

  testWidgets('commands before first layout apply after attach', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    camera.zoomTo(2, duration: Duration.zero);
    await tester.pumpWidget(_mapApp(camera: camera));
    await tester.pump();
    expect(camera.scale, 2);
    camera.dispose();
  });

  testWidgets('zoom and pan preserve persistent large-map fill batches', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    final map = _syntheticMap();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      _mapApp(camera: camera, map: map, zoomEnabled: true),
    );
    await tester.pump();
    final fills = find
        .byType(CustomPaint)
        .evaluate()
        .map((element) {
          final painter = (element.widget as CustomPaint).painter;
          return painter is RegionFillPainter ? painter : null;
        })
        .whereType<RegionFillPainter>()
        .single;
    final builds = fills.cache.fillBatchBuildCount;
    camera.zoomTo(2, duration: Duration.zero);
    camera.panBy(const Offset(20, 10));
    await tester.pump();
    expect(fills.cache.fillBatchBuildCount, builds);
  });
}

Widget _mapApp({
  required ShapeMapCameraController camera,
  ShapeMapController? controller,
  MapDefinition? map,
  bool zoomEnabled = false,
  double maxScale = 8,
  Duration cameraAnimationDuration = Duration.zero,
  Map<String, MapRegionData> data = const {'BR': MapRegionData(value: 10)},
  ShapeMapSelectionCallback? onRegionSelected,
}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 342,
        height: 400,
        child: ShapeMap(
          map: map ?? ShapeMaps.southAmerica,
          controller: controller,
          cameraController: camera,
          data: data,
          zoomEnabled: zoomEnabled,
          maxScale: maxScale,
          animationDuration: Duration.zero,
          cameraAnimationDuration: cameraAnimationDuration,
          onRegionSelected: onRegionSelected,
        ),
      ),
    ),
  );
}

Offset _anchorPoint(
  WidgetTester tester,
  MapDefinition map,
  String id,
  ShapeMapCameraController camera,
) {
  final finder = find.byType(ShapeMap);
  final transform = calculateTransform(
    map,
    tester.getSize(finder),
    BoxFit.contain,
    Alignment.center,
  );
  return camera.pan +
      transform.forward(map.regionById(id)!.markerAnchor) * camera.scale;
}

Offset _viewBoxPoint(
  WidgetTester tester,
  Offset localPoint,
  ShapeMapCameraController camera,
) {
  final transform = calculateTransform(
    ShapeMaps.southAmerica,
    tester.getSize(find.byType(ShapeMap)),
    BoxFit.contain,
    Alignment.center,
  );
  return ShapeMapCameraMath.inverse(
    transform,
    camera.scale,
    camera.pan,
    localPoint,
  );
}

MapDefinition _syntheticMap() => MapDefinition(
  id: 'synthetic',
  viewBox: const Size(400, 300),
  regions: [
    for (var index = 0; index < 1200; index++)
      MapRegion(
        id: 'R$index',
        name: 'Region $index',
        geometry: MapGeometry([
          MapPathCommand.move((index % 40) * 10, (index ~/ 40) * 10),
          MapPathCommand.horizontal((index % 40) * 10 + 9),
          MapPathCommand.vertical((index ~/ 40) * 10 + 9),
          MapPathCommand.horizontal((index % 40) * 10),
          const MapPathCommand.close(),
        ]),
        markerAnchor: Offset((index % 40) * 10 + 4, (index ~/ 40) * 10 + 4),
      ),
  ],
);

class _ResizeHarness extends StatefulWidget {
  const _ResizeHarness({required this.camera, super.key});
  final ShapeMapCameraController camera;

  @override
  State<_ResizeHarness> createState() => _ResizeHarnessState();
}

class _ResizeHarnessState extends State<_ResizeHarness> {
  double width = 300;

  @override
  void initState() {
    super.initState();
    widget.camera.addListener(_onCameraChanged);
  }

  @override
  void dispose() {
    widget.camera.removeListener(_onCameraChanged);
    super.dispose();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  void resizeTo(double value) => setState(() => width = value);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: 240,
      child: ShapeMap(
        map: ShapeMaps.southAmerica,
        cameraController: widget.camera,
        animationDuration: Duration.zero,
        cameraAnimationDuration: Duration.zero,
      ),
    ),
  );
}

class _MapSwitcher extends StatefulWidget {
  const _MapSwitcher({required this.camera, super.key});
  final ShapeMapCameraController camera;

  @override
  State<_MapSwitcher> createState() => _MapSwitcherState();
}

class _MapSwitcherState extends State<_MapSwitcher> {
  MapDefinition map = ShapeMaps.southAmerica;

  void rebuildSameMap() => setState(() {});
  void switchMap() => setState(() => map = ShapeMaps.brazilStates);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 342,
    height: 400,
    child: ShapeMap(
      map: map,
      cameraController: widget.camera,
      animationDuration: Duration.zero,
      cameraAnimationDuration: Duration.zero,
    ),
  );
}

class _ToggleMap extends StatefulWidget {
  const _ToggleMap({required this.camera, super.key});
  final ShapeMapCameraController camera;

  @override
  State<_ToggleMap> createState() => _ToggleMapState();
}

class _ToggleMapState extends State<_ToggleMap> {
  bool visible = true;

  void hide() => setState(() => visible = false);

  @override
  Widget build(BuildContext context) => visible
      ? SizedBox(
          width: 342,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmerica,
            cameraController: widget.camera,
            animationDuration: Duration.zero,
          ),
        )
      : const SizedBox.shrink();
}

Offset _inverseForTest(
  ShapeMapCameraController camera,
  Size size,
  Offset point,
) {
  final transform = calculateTransform(
    ShapeMaps.southAmerica,
    size,
    BoxFit.contain,
    Alignment.center,
  );
  return ShapeMapCameraMath.inverse(transform, camera.scale, camera.pan, point);
}

Future<void> _doubleTap(WidgetTester tester, Offset point) async {
  final first = await tester.startGesture(point);
  await first.up();
  await tester.pump(const Duration(milliseconds: 100));
  final second = await tester.startGesture(point);
  await second.up();
  await tester.pump(const Duration(milliseconds: 100));
}
