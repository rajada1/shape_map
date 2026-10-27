import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/transform.dart';
import 'package:shape_map/src/state/camera.dart';

class _FakeCameraHost implements ShapeMapCameraHost {
  int commands = 0;

  @override
  void cameraPanBy(Offset delta) => commands++;

  @override
  void cameraReset({Duration? duration, Curve? curve}) => commands++;

  @override
  void cameraZoomBy(
    double factor, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  }) => commands++;

  @override
  void cameraZoomTo(
    double scale, {
    Offset? focal,
    Duration? duration,
    Curve? curve,
  }) => commands++;

  @override
  void cameraZoomToRegion(
    String regionId, {
    double padding = 16,
    EdgeInsets insets = EdgeInsets.zero,
    Duration? duration,
    Curve? curve,
  }) => commands++;

  @override
  void cameraZoomToBounds(
    Rect viewBoxBounds, {
    EdgeInsets insets = EdgeInsets.zero,
    double padding = 16,
    Duration? duration,
    Curve? curve,
  }) => commands++;
}

void main() {
  test('camera math preserves a focal point while zooming', () {
    const base = MapTransform(2, Offset(10, 20));
    const focal = Offset(180, 120);
    final viewBoxPoint = ShapeMapCameraMath.inverse(
      base,
      1,
      Offset.zero,
      focal,
    );
    final targetPan = focal - (base.offset + viewBoxPoint * base.scale) * 3;
    expect(ShapeMapCameraMath.apply(base, 3, targetPan, viewBoxPoint), focal);
  });

  test('zoomToBounds centers content in an asymmetric visible viewport', () {
    const base = MapTransform(1, Offset.zero);
    const viewport = Size(300, 300);
    const bounds = Rect.fromLTRB(20, 20, 80, 80);
    final destination = ShapeMapCameraMath.zoomToBounds(
      base: base,
      viewBox: const Size(100, 100),
      viewport: viewport,
      viewBoxBounds: bounds,
      minScale: 1,
      maxScale: 10,
      insets: const EdgeInsets.only(top: 100, bottom: 20),
      padding: 0,
    );
    final screenCenter = ShapeMapCameraMath.apply(
      base,
      destination.scale,
      destination.pan,
      bounds.center,
    );
    expect(screenCenter.dx, closeTo(150, 1e-6));
    expect(screenCenter.dy, closeTo(190, 1e-6));
  });

  test(
    'contentBounds unions region geometry bounds and memoizes the result',
    () {
      MapGeometry geometry(
        double left,
        double top,
        double right,
        double bottom,
      ) {
        return MapGeometry([
          MapPathCommand.move(left, top),
          MapPathCommand.line(right, top),
          MapPathCommand.line(right, bottom),
          MapPathCommand.line(left, bottom),
          const MapPathCommand.close(),
        ]);
      }

      final map = MapDefinition(
        id: 'bounds',
        viewBox: const Size(100, 100),
        regions: [
          MapRegion(
            id: 'A',
            name: 'A',
            geometry: geometry(10, 20, 30, 40),
            markerAnchor: const Offset(20, 30),
          ),
          MapRegion(
            id: 'B',
            name: 'B',
            geometry: geometry(50, 5, 70, 80),
            markerAnchor: const Offset(60, 40),
          ),
        ],
      );
      final bounds = map.contentBounds;
      expect(bounds, const Rect.fromLTRB(10, 5, 70, 80));
      expect(identical(bounds, map.contentBounds), isTrue);
    },
  );

  test('camera clamp centers small content and limits large content', () {
    const base = MapTransform(1, Offset.zero);
    const viewBox = Size(100, 100);
    const viewport = Size(200, 200);
    expect(
      ShapeMapCameraMath.clampPan(
        base: base,
        viewBox: viewBox,
        viewport: viewport,
        scale: 1,
        pan: const Offset(50, 50),
      ),
      const Offset(50, 50),
    );
    expect(
      ShapeMapCameraMath.clampPan(
        base: base,
        viewBox: viewBox,
        viewport: viewport,
        scale: 3,
        pan: const Offset(1000, -1000),
      ),
      const Offset(0, -100),
    );
  });

  testWidgets('focus country ISO fits the whole country bounds', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 342,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmericaFocus('BR'),
            cameraController: camera,
            animationDuration: Duration.zero,
            cameraAnimationDuration: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pump();
    camera.zoomToRegion('BR', duration: Duration.zero);
    await tester.pump();
    expect(camera.scale, greaterThan(1));
  });
  test('controller queues commands until a map is attached', () {
    final controller = ShapeMapCameraController();
    final host = _FakeCameraHost();
    controller.zoomBy(2);
    expect(host.commands, 0);
    controller.attach(host);
    expect(host.commands, 1);
    controller.detach(host);
  });

  testWidgets('programmatic camera zoom updates hit testing and selection', (
    tester,
  ) async {
    final camera = ShapeMapCameraController();
    MapRegion? selected;
    MapRegion? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 342,
          height: 400,
          child: ShapeMap(
            map: ShapeMaps.southAmerica,
            cameraController: camera,
            animationDuration: Duration.zero,
            cameraAnimationDuration: Duration.zero,
            onRegionSelected: (region) => selected = region,
            onRegionTap: (region) => tapped = region,
          ),
        ),
      ),
    );
    await tester.pump();
    camera.zoomTo(2, focal: const Offset(170, 200));
    await tester.pump();
    final mapFinder = find.byType(ShapeMap);
    final transform = calculateTransform(
      ShapeMaps.southAmerica,
      tester.getSize(mapFinder),
      BoxFit.contain,
      Alignment.center,
    );
    final anchor = ShapeMaps.southAmerica.regionById('BR')!.markerAnchor;
    final point = camera.pan + transform.forward(anchor) * camera.scale;
    await tester.tapAt(tester.getTopLeft(mapFinder) + point);
    await tester.pump();
    expect(tapped?.id, 'BR');
    expect(selected?.id, 'BR');
  });
}
