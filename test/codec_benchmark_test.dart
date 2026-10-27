// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  test('prints decode benchmark for world and municipalities', () async {
    final worldWatch = Stopwatch()..start();
    final world = ShapeMaps.world;
    worldWatch.stop();
    final asset = File('example/assets/maps/brazil_municipalities.smap');
    if (!asset.existsSync()) {
      print('decode benchmark: world=${worldWatch.elapsedMicroseconds}us');
      expect(world.regions, isNotEmpty);
      return;
    }
    final bytes = await asset.readAsBytes();
    final municipalityWatch = Stopwatch()..start();
    final municipalities = await ShapeMapData.decode(
      ByteData.sublistView(Uint8List.fromList(bytes)),
      id: 'benchmark',
    );
    municipalityWatch.stop();
    print(
      'decode benchmark: world=${worldWatch.elapsedMicroseconds}us, '
      'municipalities=${municipalityWatch.elapsedMicroseconds}us, '
      'bytes=${bytes.length}',
    );
    expect(municipalities.regions, hasLength(5570));
  });
}
