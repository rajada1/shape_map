import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/rendering/painters.dart';
import 'package:shape_map/src/rendering/transform.dart';

void main() {
  test(
    'large-map tiles cull at high zoom and draw all populated tiles at scale one',
    () {
      final definition = _syntheticMap();
      final cache = MapRenderCache()
        ..update(
          definition,
          const Size(800, 600),
          BoxFit.contain,
          Alignment.center,
        )
        ..updateFillBatches(const {}, Colors.grey, Colors.white)
        ..updateBorder(Colors.black, 1);
      final camera = ShapeMapCameraController();
      final animation = const AlwaysStoppedAnimation<double>(1);
      final painter = RegionFillPainter(
        definition: definition,
        cache: cache,
        data: const {},
        previousData: const {},
        style: const ShapeMapStyle(),
        animation: animation,
        progress: animation,
        entrance: null,
        repaint: animation,
        camera: camera,
      );
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(800, 600));
      recorder.endRecording().dispose();
      final allTiles = painter.tilesDrawn;
      expect(allTiles, cache.fillTileCount);

      camera.updateFromHost(20, const Offset(-400, -500));
      final zoomedRecorder = PictureRecorder();
      painter.paint(Canvas(zoomedRecorder), const Size(800, 600));
      zoomedRecorder.endRecording().dispose();
      expect(painter.tilesDrawn, lessThan(allTiles));

      final borderPainter = RegionBorderPainter(
        cache: cache,
        definition: definition,
        style: const ShapeMapStyle(),
        progress: animation,
        entrance: null,
        repaint: animation,
        camera: camera,
      );
      final borderRecorder = PictureRecorder();
      borderPainter.paint(Canvas(borderRecorder), const Size(800, 600));
      borderRecorder.endRecording().dispose();
      expect(borderPainter.tilesDrawn, lessThan(cache.borderTiles.length));
      camera.dispose();
      cache.dispose();
    },
  );

  test('nearby border camera scales share a bucket', () {
    final cache = MapRenderCache()
      ..update(
        _syntheticMap(),
        const Size(800, 600),
        BoxFit.contain,
        Alignment.center,
      );
    cache.updateBorder(Colors.black, 1, cameraScale: 1);
    final first = cache.borderRecordCount;
    cache.updateBorder(Colors.black, 1, cameraScale: 1.05);
    expect(cache.borderRecordCount, first);
    cache.updateBorder(Colors.black, 1, cameraScale: 1.3);
    expect(cache.borderRecordCount, first + 1);
    cache.dispose();
  });
}

MapDefinition _syntheticMap() => MapDefinition(
  id: 'synthetic-tiling',
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
