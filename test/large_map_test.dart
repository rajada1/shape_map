import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/src/rendering/painters.dart';
import 'package:shape_map/src/rendering/transform.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('large maps use one canvas transform and grouped stagger paths', () {
    final regions = [
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
    ];
    final definition = MapDefinition(
      id: 'synthetic',
      viewBox: const Size(400, 300),
      regions: regions,
    );
    final cache = MapRenderCache();
    cache.update(
      definition,
      const Size(800, 600),
      BoxFit.contain,
      Alignment.center,
    );
    cache.updateStagger(ShapeMapStaggerOrder.topToBottom);
    expect(cache.usesCanvasTransform, isTrue);
    expect(cache.staggerGroupPaths.length, lessThanOrEqualTo(48));
    cache.dispose();
  });

  test('large-map fills stay grouped during data and fade transitions', () {
    final definition = _syntheticMap();
    final cache = MapRenderCache();
    cache.update(
      definition,
      const Size(800, 600),
      BoxFit.contain,
      Alignment.center,
    );
    final first = <String, MapRegionData>{
      for (final region in definition.regions)
        region.id: MapRegionData(
          fill: [
            Colors.red,
            Colors.green,
            Colors.blue,
          ][int.parse(region.id.substring(1)) % 3],
        ),
    };
    final second = <String, MapRegionData>{
      for (final region in definition.regions)
        region.id: MapRegionData(
          fill: [
            Colors.orange,
            Colors.purple,
            Colors.teal,
          ][int.parse(region.id.substring(1)) % 3],
        ),
    };
    cache.updateFillBatches(first, Colors.grey, Colors.white);
    final builds = cache.fillBatchBuildCount;
    cache.updateFillBatches(Map.of(first), Colors.grey, Colors.white);
    expect(cache.fillBatchBuildCount, builds);
    cache.updateFillBatches(second, Colors.grey, Colors.white);

    final animation = const AlwaysStoppedAnimation<double>(0.5);
    final painter = RegionFillPainter(
      definition: definition,
      cache: cache,
      data: second,
      previousData: first,
      style: const ShapeMapStyle(),
      animation: animation,
      progress: const AlwaysStoppedAnimation<double>(1),
      entrance: null,
      repaint: animation,
    );
    final recorder = PictureRecorder();
    painter.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording().dispose();
    expect(painter.fillBatchDrawCount, lessThanOrEqualTo(2 * 3));

    final fadePainter = RegionFillPainter(
      definition: definition,
      cache: cache,
      data: second,
      previousData: first,
      style: const ShapeMapStyle(),
      animation: const AlwaysStoppedAnimation<double>(1),
      progress: const AlwaysStoppedAnimation<double>(0.5),
      entrance: const ShapeMapEntrance(style: ShapeMapEntranceStyle.fade),
      repaint: animation,
    );
    final fadeRecorder = PictureRecorder();
    fadePainter.paint(Canvas(fadeRecorder), const Size(800, 600));
    fadeRecorder.endRecording().dispose();
    expect(fadePainter.fillBatchDrawCount, lessThanOrEqualTo(3));
    cache.dispose();
  });

  test('large-map border picture survives a layout-only resize', () {
    final definition = _syntheticMap();
    final cache = MapRenderCache();
    cache.update(
      definition,
      const Size(800, 600),
      BoxFit.contain,
      Alignment.center,
    );
    cache.updateBorder(Colors.black, 1);
    final picture = cache.borderPicture;
    cache.update(
      definition,
      const Size(600, 800),
      BoxFit.contain,
      Alignment.center,
    );
    cache.updateBorder(Colors.black, 1);
    expect(identical(cache.borderPicture, picture), isTrue);
    cache.dispose();
  });

  test('large-map synthetic geometry has persistent batches', () {
    final definition = _syntheticMap();
    final cache = MapRenderCache();
    cache.update(
      definition,
      const Size(800, 600),
      BoxFit.contain,
      Alignment.center,
    );
    cache.updateFillBatches(const {}, Colors.grey, Colors.white);
    final firstBuild = cache.fillBatchBuildCount;
    cache.updateFillBatches(const {}, Colors.grey, Colors.white);
    expect(cache.fillBatchBuildCount, firstBuild);
    cache.dispose();
  });
  test('large-map stagger fill groups stay homogeneous by color', () {
    final definition = _syntheticMap();
    final colors = [Colors.red, Colors.green, Colors.blue];
    final data = <String, MapRegionData>{
      for (var index = 0; index < definition.regions.length; index++)
        'R$index': MapRegionData(fill: colors[index % colors.length]),
    };
    final cache = MapRenderCache();
    cache.update(
      definition,
      const Size(800, 600),
      BoxFit.contain,
      Alignment.center,
    );
    cache.updateFillBatches(data, Colors.grey, Colors.white);
    cache.updateStagger(ShapeMapStaggerOrder.topToBottom);

    expect(
      cache.staggerFillGroupPaths.length,
      cache.staggerFillGroupColors.length,
    );
    for (var group = 0; group < cache.staggerFillGroupPaths.length; group++) {
      final color = cache.staggerFillGroupColors[group];
      final indices = cache.staggerFillGroupRegionIndices[group];
      expect(indices.length, cache.staggerFillGroupRegionCounts[group]);
      expect(indices.every((index) => data['R$index']!.fill == color), isTrue);
    }

    final animation = const AlwaysStoppedAnimation<double>(1);
    final painter = RegionFillPainter(
      definition: definition,
      cache: cache,
      data: data,
      previousData: const {},
      style: const ShapeMapStyle(),
      animation: animation,
      progress: const AlwaysStoppedAnimation<double>(0.5),
      entrance: const ShapeMapEntrance(style: ShapeMapEntranceStyle.stagger),
      repaint: animation,
    );
    final recorder = PictureRecorder();
    painter.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording().dispose();
    expect(painter.drawCalls, greaterThan(0));
    cache.dispose();
  });

  test('large-map fill pictures keep draw calls independent of colors', () {
    final definition = _syntheticMap();
    Map<String, MapRegionData> data(int offset) => {
      for (var index = 0; index < definition.regions.length; index++)
        'R$index': MapRegionData(
          fill: Color(0xFF000000 | ((index + offset) & 0x00FFFFFF)),
        ),
    };
    final cache = MapRenderCache();
    cache.update(
      definition,
      const Size(800, 600),
      BoxFit.contain,
      Alignment.center,
    );
    final first = data(0);
    cache.updateFillBatches(first, Colors.grey, Colors.white);
    final stable = RegionFillPainter(
      definition: definition,
      cache: cache,
      data: first,
      previousData: const {},
      style: const ShapeMapStyle(),
      animation: const AlwaysStoppedAnimation<double>(1),
      progress: const AlwaysStoppedAnimation<double>(1),
      entrance: null,
      repaint: const AlwaysStoppedAnimation<double>(1),
    );
    var recorder = PictureRecorder();
    stable.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording().dispose();
    expect(stable.drawCalls, lessThanOrEqualTo(4));

    final second = data(1200);
    cache.updateFillBatches(second, Colors.grey, Colors.white);
    final crossfade = RegionFillPainter(
      definition: definition,
      cache: cache,
      data: second,
      previousData: first,
      style: const ShapeMapStyle(),
      animation: const AlwaysStoppedAnimation<double>(0.5),
      progress: const AlwaysStoppedAnimation<double>(1),
      entrance: null,
      repaint: const AlwaysStoppedAnimation<double>(1),
    );
    recorder = PictureRecorder();
    crossfade.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording().dispose();
    expect(crossfade.drawCalls, lessThanOrEqualTo(4));

    final fade = RegionFillPainter(
      definition: definition,
      cache: cache,
      data: second,
      previousData: first,
      style: const ShapeMapStyle(),
      animation: const AlwaysStoppedAnimation<double>(1),
      progress: const AlwaysStoppedAnimation<double>(0.5),
      entrance: const ShapeMapEntrance(style: ShapeMapEntranceStyle.fade),
      repaint: const AlwaysStoppedAnimation<double>(1),
    );
    recorder = PictureRecorder();
    fade.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording().dispose();
    expect(fade.drawCalls, lessThanOrEqualTo(4));
    cache.dispose();
  });
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
