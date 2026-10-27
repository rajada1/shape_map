import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/markers.dart';
import 'package:shape_map/src/rendering/transform.dart';

void main() {
  test('marker outside the viewport produces no drawCircle', () {
    final map = MapDefinition(
      id: 'marker-culling',
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
            position: Offset(200, 200),
            showLabel: false,
          ),
        ],
        const MarkerStyle(),
        const {},
      );
    final animation = const AlwaysStoppedAnimation<double>(1);
    final painter = MarkerPainter(
      cache: cache,
      layoutCache: layout,
      style: const MarkerStyle(),
      animation: animation,
      progress: animation,
      entrance: null,
      repaint: animation,
    );
    final canvas = TestRecordingCanvas();
    painter.paint(canvas, const Size(200, 200));
    expect(
      canvas.invocations.where(
        (entry) => entry.invocation.memberName == #drawCircle,
      ),
      isEmpty,
    );
    layout.dispose();
    cache.dispose();
  });
}
