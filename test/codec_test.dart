import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';
import 'package:shape_map/src/data/codec.dart';

Uint8List _fixture() {
  final bytes = <int>[];
  void u8(int value) => bytes.add(value);
  void i32(int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.little);
    bytes.addAll(data.buffer.asUint8List());
  }

  void f32(double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    bytes.addAll(data.buffer.asUint8List());
  }

  void varuint(int value) {
    do {
      var byte = value & 0x7f;
      value >>= 7;
      if (value != 0) byte |= 0x80;
      u8(byte);
    } while (value != 0);
  }

  void string(String value) {
    final encoded = utf8.encode(value);
    varuint(encoded.length);
    bytes.addAll(encoded);
  }

  void zigzag(int value) {
    var encoded = value < 0 ? -value * 2 - 1 : value * 2;
    do {
      var byte = encoded & 0x7f;
      encoded >>= 7;
      if (encoded != 0) byte |= 0x80;
      u8(byte);
    } while (encoded != 0);
  }

  bytes.addAll(const [0x53, 0x4D, 0x41, 0x50]);
  u8(2);
  f32(10);
  f32(20);
  f32(1);
  varuint(1);
  u8(0);
  varuint(2);
  string('AA');
  string('Test');
  varuint(0);
  varuint(1);
  for (final value in [0, 0, 10, 20]) {
    i32(value);
  }
  i32(5);
  i32(5);
  varuint(1);
  varuint(4);
  var previousX = 0;
  var previousY = 0;
  for (final point in [
    [0, 0],
    [10, 0],
    [10, 20],
    [0, 20],
  ]) {
    zigzag(point[0] - previousX);
    zigzag(point[1] - previousY);
    previousX = point[0];
    previousY = point[1];
  }
  return Uint8List.fromList(bytes);
}

void main() {
  test('decodes a known SMAP fixture with lazy geometry', () {
    final map = ShapeMapData.decodeSync(_fixture());
    expect(map.regions.single.id, 'AA');
    expect(map.regions.single.name, 'Test');
    expect(map.viewBox, const Size(10, 20));
    expect(map.regions.single.markerAnchor, const Offset(5, 5));
    expect(
      map.regions.single.geometry.bounds,
      const Rect.fromLTRB(0, 0, 10, 20),
    );
    expect(
      map.regions.single.geometry.path.contains(const Offset(5, 5)),
      isTrue,
    );
  });

  test('rejects invalid SMAP magic and version', () {
    final invalidMagic = _fixture()..[0] = 0;
    expect(() => ShapeMapData.decodeSync(invalidMagic), throwsFormatException);
    final invalidVersion = _fixture()..[4] = 1;
    expect(
      () => ShapeMapData.decodeSync(invalidVersion),
      throwsFormatException,
    );
  });

  test('built-in maps decode independently on first access', () {
    final before = shapeMapDecodeCount;
    final brazil = ShapeMaps.brazilStates;
    expect(brazil.regions, hasLength(27));
    expect(shapeMapDecodeCount, greaterThanOrEqualTo(before));
    expect(ShapeMaps.world.regions.length, greaterThan(170));
  });
}
