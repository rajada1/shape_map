"""Verify the generated Brazil golden contains southern Rio Grande do Sul."""
from __future__ import annotations

import base64
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DART = ROOT / "lib/src/data/generated/brazil_states.g.dart"
PNG = ROOT / "test/goldens/brazil_states.png"


def varuint(data: bytes, offset: int) -> tuple[int, int]:
    value = 0
    shift = 0
    while True:
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, offset
        shift += 7


def read_map_anchor(region_id: str) -> tuple[float, float, float, float]:
    source = DART.read_text()
    encoded = re.search(r"const String _data\s*=\s*'([^']+)';", source, re.DOTALL).group(1)
    data = base64.b64decode(encoded)
    if data[:4] != b"SMAP" or data[4] != 2:
        raise ValueError("expected SMAP v2")
    width, height, scale = struct.unpack_from("<fff", data, 5)
    offset = 17
    region_count, offset = varuint(data, offset)
    offset += 1  # flags
    string_count, offset = varuint(data, offset)
    strings = []
    for _ in range(string_count):
        length, offset = varuint(data, offset)
        strings.append(data[offset : offset + length].decode())
        offset += length
    for _ in range(region_count):
        id_index, offset = varuint(data, offset)
        _, offset = varuint(data, offset)  # name index
        offset += 16  # bbox
        x, y = struct.unpack_from("<ii", data, offset)
        offset += 8
        ring_count, offset = varuint(data, offset)
        for _ in range(ring_count):
            point_count, offset = varuint(data, offset)
            for _ in range(point_count * 2):
                _, offset = varuint(data, offset)  # zigzag coordinate delta
        if strings[id_index] == region_id:
            return x * scale, y * scale, width, height
    raise ValueError(f"missing {region_id}")


def pixels(path: Path) -> tuple[int, int, bytes]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    offset = 8
    compressed = bytearray()
    width = height = color_type = bit_depth = None
    while offset < len(raw):
        length = struct.unpack_from(">I", raw, offset)[0]
        kind = raw[offset + 4 : offset + 8]
        chunk = raw[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or color_type != 6 or interlace:
                raise ValueError("expected non-interlaced RGBA8 PNG")
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    decoded = zlib.decompress(compressed)
    stride = width * 4
    rows = []
    previous = bytearray(stride)
    cursor = 0
    for _ in range(height):
        filter_type = decoded[cursor]
        cursor += 1
        row = bytearray(decoded[cursor : cursor + stride])
        cursor += stride
        for i in range(stride):
            left = row[i - 4] if i >= 4 else 0
            up = previous[i]
            upper_left = previous[i - 4] if i >= 4 else 0
            if filter_type == 1:
                row[i] = (row[i] + left) & 255
            elif filter_type == 2:
                row[i] = (row[i] + up) & 255
            elif filter_type == 3:
                row[i] = (row[i] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                estimate = left + up - upper_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - upper_left))
                predictor = (left, up, upper_left)[distances.index(min(distances))]
                row[i] = (row[i] + predictor) & 255
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        rows.append(row)
        previous = row
    return width, height, b"".join(rows)


x, y, view_width, view_height = read_map_anchor("BR-RS")
width, height, image = pixels(PNG)
if width != round(view_width) or height != round(view_height):
    raise AssertionError(f"unexpected image size: {width}x{height}")
if y <= height / 2:
    raise AssertionError(f"BR-RS anchor is not in the lower half: y={y}")
ix, iy = round(x), round(y)
alpha = image[(iy * width + ix) * 4 + 3]
if alpha == 0:
    raise AssertionError(f"BR-RS anchor pixel is transparent at ({ix}, {iy})")
print(f"BR-RS anchor ({x:.2f}, {y:.2f}) is below the midpoint; pixel alpha={alpha}")
