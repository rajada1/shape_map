import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/data/codec.dart';

void main() {
  // Each test file runs in its own isolate, so `world` has not been decoded
  // yet when this test starts.
  test('preload decodes off the sync path and getters reuse it', () async {
    final syncDecodesBefore = shapeMapDecodeCount;
    await ShapeMaps.preload([ShapeMapId.world]);
    final world = ShapeMaps.world;
    expect(shapeMapDecodeCount, syncDecodesBefore, reason: 'no sync decode');
    expect(world.regions.length, greaterThan(170));
    expect(identical(ShapeMaps.world, world), isTrue);
  });

  test('preload is a no-op for maps already decoded', () async {
    final before = ShapeMaps.brazilStates;
    final decodeCount = shapeMapDecodeCount;
    await ShapeMaps.preload([ShapeMapId.brazilStates]);
    expect(identical(ShapeMaps.brazilStates, before), isTrue);
    expect(shapeMapDecodeCount, decodeCount);
  });
}
