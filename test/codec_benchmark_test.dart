// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'prints decode benchmark for world, largest focus and municipalities',
    () async {
      final worldWatch = Stopwatch()..start();
      final world = ShapeMaps.world;
      worldWatch.stop();

      final largestFocusWatch = Stopwatch()..start();
      final largestFocus = await ShapeMaps.loadCountryFocus('RU');
      largestFocusWatch.stop();

      final asset = File('example/assets/maps/brazil_municipalities.smap');
      if (!asset.existsSync()) {
        print(
          'decode benchmark: world=${worldWatch.elapsedMicroseconds}us, '
          'largestFocus=${largestFocusWatch.elapsedMicroseconds}us, '
          'largestFocusRegions=${largestFocus.regions.length}',
        );
        expect(world.regions, isNotEmpty);
        expect(largestFocus.focusBounds, isNotNull);
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
        'largestFocus=${largestFocusWatch.elapsedMicroseconds}us, '
        'municipalities=${municipalityWatch.elapsedMicroseconds}us, '
        'largestFocusRegions=${largestFocus.regions.length}, '
        'municipalitiesBytes=${bytes.length}',
      );
      expect(municipalities.regions, hasLength(5570));
    },
  );
}
