import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'models.dart';

const _magic = <int>[0x53, 0x4D, 0x41, 0x50];
const _version = 2;
const _innerBordersFlag = 1;
const _outlineFlag = 2;

/// Number of embedded maps decoded, exposed for lazy-loading tests.
int shapeMapDecodeCount = 0;

/// Decodes one generated map and increments the testing counter.
MapDefinition decodeGenerated(
  Uint8List bytes, {
  required String id,
  String? focusRegionPrefix,
}) {
  shapeMapDecodeCount++;
  return ShapeMapData.decodeSync(
    bytes,
    id: id,
    focusRegionPrefix: focusRegionPrefix,
  );
}

/// Decodes an embedded base64 map off the UI isolate without touching the
/// synchronous decode counter.
Future<MapDefinition> decodeGeneratedAsync(
  String encoded, {
  required String id,
  String? focusRegionPrefix,
}) async {
  final decoded = await Isolate.run(() => _parse(base64Decode(encoded)));
  return _materialize(decoded, id: id, focusRegionPrefix: focusRegionPrefix);
}

/// SMAP v2 decoder for embedded and application-provided map data.
abstract final class ShapeMapData {
  /// Decodes [bytes] synchronously on the current isolate.
  static MapDefinition decodeSync(
    Uint8List bytes, {
    String? id,
    String? focusRegionPrefix,
  }) =>
      _materialize(_parse(bytes), id: id, focusRegionPrefix: focusRegionPrefix);

  /// Decodes [bytes] off the UI isolate and materializes lazy map geometry.
  ///
  /// The isolate returns flat typed buffers rather than nested coordinate
  /// lists. This keeps the transfer and materialization cost proportional to
  /// the compact binary payload and does not construct any [Path] eagerly.
  static Future<MapDefinition> decode(
    ByteData bytes, {
    String? id,
    String? focusRegionPrefix,
  }) async {
    final raw = Uint8List.sublistView(
      bytes.buffer.asUint8List(),
      bytes.offsetInBytes,
      bytes.offsetInBytes + bytes.lengthInBytes,
    );
    final decoded = await Isolate.run(() => _parse(raw));
    return _materialize(decoded, id: id, focusRegionPrefix: focusRegionPrefix);
  }
}

Map<String, Object> _parse(Uint8List bytes) {
  final reader = _Reader(bytes);
  for (final expected in _magic) {
    if (reader.u8() != expected) {
      throw const FormatException('Invalid SMAP magic; expected SMAP.');
    }
  }
  final version = reader.u8();
  if (version != _version) {
    throw FormatException('Unsupported SMAP version $version; expected 2.');
  }
  final width = reader.f32();
  final height = reader.f32();
  final scale = reader.f32();
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    throw const FormatException('SMAP viewBox must contain positive values.');
  }
  if (!scale.isFinite || scale <= 0) {
    throw const FormatException('SMAP quantization scale must be positive.');
  }
  final regionCount = reader.varuint();
  final flags = reader.u8();
  if ((flags & ~(_innerBordersFlag | _outlineFlag)) != 0) {
    throw const FormatException('SMAP contains unknown stream flags.');
  }
  final strings = _readStrings(reader);
  String stringAt(int index) {
    if (index < 0 || index >= strings.length) {
      throw const FormatException('SMAP string index is out of range.');
    }
    return strings[index];
  }

  final ids = <String>[];
  final names = <String>[];
  final bboxes = Int32List(regionCount * 4);
  final anchors = Int32List(regionCount * 2);
  final coordinates = <int>[];
  final ringOffsets = <int>[0];
  final regionRingStart = Uint32List(regionCount + 1);
  for (var region = 0; region < regionCount; region++) {
    ids.add(stringAt(reader.varuint()));
    names.add(stringAt(reader.varuint()));
    final bboxOffset = region * 4;
    for (var i = 0; i < 4; i++) {
      bboxes[bboxOffset + i] = reader.i32();
    }
    final anchorOffset = region * 2;
    anchors[anchorOffset] = reader.i32();
    anchors[anchorOffset + 1] = reader.i32();
    regionRingStart[region] = ringOffsets.length - 1;
    _readRings(reader, coordinates, ringOffsets);
  }
  regionRingStart[regionCount] = ringOffsets.length - 1;

  final inner = flags & _innerBordersFlag != 0
      ? _readLines(reader)
      : _EmptyLines();
  final outline = flags & _outlineFlag != 0
      ? _readLines(reader)
      : _EmptyLines();

  return <String, Object>{
    'width': width,
    'height': height,
    'scale': scale,
    'ids': ids,
    'names': names,
    'bboxes': bboxes,
    'anchors': anchors,
    'coordinates': Int32List.fromList(coordinates),
    'ringOffsets': Uint32List.fromList(ringOffsets),
    'regionRingStart': regionRingStart,
    'innerCoordinates': inner.coordinates,
    'innerOffsets': inner.offsets,
    'outlineCoordinates': outline.coordinates,
    'outlineOffsets': outline.offsets,
  };
}

List<String> _readStrings(_Reader reader) {
  final count = reader.varuint();
  final strings = <String>[];
  for (var i = 0; i < count; i++) {
    final length = reader.varuint();
    strings.add(utf8.decode(reader.bytes(length), allowMalformed: false));
  }
  return strings;
}

void _readRings(_Reader reader, List<int> coordinates, List<int> offsets) {
  final ringCount = reader.varuint();
  for (var ring = 0; ring < ringCount; ring++) {
    final pointCount = reader.varuint();
    if (pointCount < 3) {
      throw const FormatException('SMAP polygon ring must have 3 points.');
    }
    var x = reader.zigzag();
    var y = reader.zigzag();
    coordinates.addAll([x, y]);
    for (var point = 1; point < pointCount; point++) {
      x += reader.zigzag();
      y += reader.zigzag();
      coordinates.addAll([x, y]);
    }
    offsets.add(coordinates.length);
  }
}

_Lines _readLines(_Reader reader) {
  final lineCount = reader.varuint();
  final coordinates = <int>[];
  final offsets = <int>[0];
  for (var line = 0; line < lineCount; line++) {
    final pointCount = reader.varuint();
    if (pointCount < 2) {
      throw const FormatException('SMAP polyline must have 2 points.');
    }
    var x = reader.zigzag();
    var y = reader.zigzag();
    coordinates.addAll([x, y]);
    for (var point = 1; point < pointCount; point++) {
      x += reader.zigzag();
      y += reader.zigzag();
      coordinates.addAll([x, y]);
    }
    offsets.add(coordinates.length);
  }
  return _Lines(Int32List.fromList(coordinates), Uint32List.fromList(offsets));
}

class _EmptyLines extends _Lines {
  _EmptyLines() : super(Int32List(0), Uint32List.fromList([0]));
}

class _Lines {
  const _Lines(this.coordinates, this.offsets);
  final Int32List coordinates;
  final Uint32List offsets;
}

MapDefinition _materialize(
  Map<String, Object> decoded, {
  String? id,
  String? focusRegionPrefix,
}) {
  final scale = decoded['scale']! as double;
  final ids = decoded['ids']! as List<String>;
  final names = decoded['names']! as List<String>;
  final bboxes = decoded['bboxes']! as Int32List;
  final anchors = decoded['anchors']! as Int32List;
  final coordinates = decoded['coordinates']! as Int32List;
  final ringOffsets = decoded['ringOffsets']! as Uint32List;
  final regionRingStart = decoded['regionRingStart']! as Uint32List;
  final regions = <MapRegion>[];
  for (var i = 0; i < ids.length; i++) {
    final bbox = i * 4;
    final anchor = i * 2;
    regions.add(
      MapRegion(
        id: ids[i],
        name: names[i],
        geometry: MapGeometry.fromQuantizedBuffers(
          coordinates: coordinates,
          ringOffsets: ringOffsets,
          ringStart: regionRingStart[i],
          ringCount: regionRingStart[i + 1] - regionRingStart[i],
          scale: scale,
          bounds: Rect.fromLTRB(
            bboxes[bbox] * scale,
            bboxes[bbox + 1] * scale,
            bboxes[bbox + 2] * scale,
            bboxes[bbox + 3] * scale,
          ),
        ),
        markerAnchor: Offset(
          anchors[anchor] * scale,
          anchors[anchor + 1] * scale,
        ),
      ),
    );
  }
  final innerCoordinates = decoded['innerCoordinates']! as Int32List;
  final innerOffsets = decoded['innerOffsets']! as Uint32List;
  final outlineCoordinates = decoded['outlineCoordinates']! as Int32List;
  final outlineOffsets = decoded['outlineOffsets']! as Uint32List;
  return MapDefinition(
    id: id ?? 'decoded',
    viewBox: Size(decoded['width']! as double, decoded['height']! as double),
    regions: regions,
    innerBorders: [
      for (var i = 0; i + 1 < innerOffsets.length; i++)
        MapPolyline.fromQuantizedBuffers(
          coordinates: innerCoordinates,
          lineOffsets: innerOffsets,
          lineStart: i,
          lineCount: 1,
          scale: scale,
        ),
    ],
    outline: [
      for (var i = 0; i + 1 < outlineOffsets.length; i++)
        MapPolyline.fromQuantizedBuffers(
          coordinates: outlineCoordinates,
          lineOffsets: outlineOffsets,
          lineStart: i,
          lineCount: 1,
          scale: scale,
        ),
    ],
    focusRegionPrefix: focusRegionPrefix,
  );
}

class _Reader {
  _Reader(this.raw) : data = ByteData.sublistView(raw);
  final Uint8List raw;
  final ByteData data;
  var offset = 0;

  void _require(int count) {
    if (count < 0 || offset + count > raw.length) {
      throw const FormatException('Unexpected end of SMAP data.');
    }
  }

  int u8() {
    _require(1);
    return raw[offset++];
  }

  int i32() {
    _require(4);
    final value = data.getInt32(offset, Endian.little);
    offset += 4;
    return value;
  }

  double f32() {
    _require(4);
    final value = data.getFloat32(offset, Endian.little);
    offset += 4;
    return value;
  }

  Uint8List bytes(int count) {
    _require(count);
    final result = Uint8List.sublistView(raw, offset, offset + count);
    offset += count;
    return result;
  }

  int varuint() {
    var value = 0;
    var shift = 0;
    while (true) {
      final byte = u8();
      value |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return value;
      shift += 7;
      if (shift > 28) throw const FormatException('Invalid SMAP varint.');
    }
  }

  int zigzag() {
    var value = 0;
    var shift = 0;
    while (true) {
      final byte = u8();
      value |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) break;
      shift += 7;
      if (shift > 28) throw const FormatException('Invalid SMAP varint.');
    }
    return (value >> 1) ^ -(value & 1);
  }
}
