// Offline map compiler for shape_map. Run through tool/generate_maps.dart.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import mapshaper from 'mapshaper';
import polylabel from 'polylabel';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const cacheDir = path.join(here, '../.cache');
const manifestPath = path.join(here, 'sources.json');
const namesPath = path.join(here, 'names_pt.json');
const generatedDir = path.join(root, 'lib/src/data/generated');
const exampleAssetsDir = path.join(root, 'example/assets/maps');
fs.mkdirSync(cacheDir, { recursive: true });
fs.mkdirSync(generatedDir, { recursive: true });
fs.mkdirSync(exampleAssetsDir, { recursive: true });

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const overrides = JSON.parse(fs.readFileSync(namesPath, 'utf8'));
const normalizationBoundsByProjection = new Map();

async function source(name) {
  const item = manifest[name];
  const extension = item.url.includes('.zip') ? '.zip' : '.json';
  const target = path.join(cacheDir, `${name}${extension}`);
  if (!fs.existsSync(target)) {
    const response = await fetch(item.url);
    if (!response.ok) throw new Error(`Download failed (${response.status}): ${item.url}`);
    fs.writeFileSync(target, Buffer.from(await response.arrayBuffer()));
  }
  const actual = crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex');
  if (!item.sha256) {
    item.sha256 = actual;
    fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    console.log(`Recorded sha256 ${name}: ${actual}`);
  } else if (item.sha256 !== actual) {
    throw new Error(`SHA-256 mismatch for ${name}: expected ${item.sha256}, got ${actual}`);
  }
  return target;
}

function runMapshaper(command) {
  return new Promise((resolve, reject) => {
    mapshaper.runCommands(command, (error, output) => {
      if (error) reject(error); else resolve(output);
    });
  });
}

async function convertToGeoJson(input, output) {
  await runMapshaper(`-i ${quote(input)} -o format=geojson ${quote(output)}`);
  return JSON.parse(fs.readFileSync(output, 'utf8'));
}

function quote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

function featureParts(feature) {
  const geometry = feature.geometry;
  if (!geometry) return [];
  if (geometry.type === 'Polygon') return [geometry.coordinates];
  if (geometry.type === 'MultiPolygon') return geometry.coordinates;
  return [];
}

function partBounds(part) {
  let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
  for (const ring of part) for (const point of ring) {
    minX = Math.min(minX, point[0]); minY = Math.min(minY, point[1]);
    maxX = Math.max(maxX, point[0]); maxY = Math.max(maxY, point[1]);
  }
  return { minX, minY, maxX, maxY };
}

function extractFrenchGuiana(feature) {
  const parts = featureParts(feature);
  const gf = parts.filter((part) => {
    const b = partBounds(part);
    return b.minX > -56 && b.maxX < -50 && b.minY > 1 && b.maxY < 7;
  });
  return gf;
}

function withoutFrenchGuiana(feature) {
  const parts = featureParts(feature).filter((part) => {
    const b = partBounds(part);
    return !(b.minX > -56 && b.maxX < -50 && b.minY > 1 && b.maxY < 7);
  });
  const type = parts.length === 1 ? 'Polygon' : 'MultiPolygon';
  return { ...feature, geometry: { type, coordinates: parts.length === 1 ? parts[0] : parts } };
}

const alpha2ByA3 = {
  ABW:'AW', AFG:'AF', AGO:'AO', AIA:'AI', ALA:'AX', ALB:'AL', AND:'AD', ARE:'AE', ARG:'AR', ARM:'AM', ASM:'AS', ATA:'AQ', ATF:'TF', ATG:'AG', AUS:'AU', AUT:'AT', AZE:'AZ', BDI:'BI', BEL:'BE', BEN:'BJ', BES:'BQ', BFA:'BF', BGD:'BD', BGR:'BG', BHR:'BH', BHS:'BS', BIH:'BA', BLM:'BL', BLR:'BY', BLZ:'BZ', BMU:'BM', BOL:'BO', BRA:'BR', BRB:'BB', BRN:'BN', BTN:'BT', BWA:'BW', CAF:'CF', CAN:'CA', CHE:'CH', CHL:'CL', CHN:'CN', CIV:'CI', CMR:'CM', COD:'CD', COG:'CG', COK:'CK', COL:'CO', COM:'KM', CPV:'CV', CRI:'CR', CUB:'CU', CUW:'CW', CXR:'CX', CYM:'KY', CYP:'CY', CZE:'CZ', DEU:'DE', DJI:'DJ', DMA:'DM', DNK:'DK', DOM:'DO', DZA:'DZ', ECU:'EC', EGY:'EG', ERI:'ER', ESH:'EH', ESP:'ES', EST:'EE', ETH:'ET', FIN:'FI', FJI:'FJ', FLK:'FK', FRA:'FR', FRO:'FO', FSM:'FM', GAB:'GA', GBR:'GB', GEO:'GE', GG:'GG', GHA:'GH', GIB:'GI', GIN:'GN', GLP:'GP', GMB:'GM', GNB:'GW', GNQ:'GQ', GRC:'GR', GRD:'GD', GRL:'GL', GTM:'GT', GUF:'GF', GUM:'GU', GUY:'GY', HKG:'HK', HND:'HN', HRV:'HR', HTI:'HT', HUN:'HU', IDN:'ID', IMN:'IM', IND:'IN', IOT:'IO', IRL:'IE', IRN:'IR', IRQ:'IQ', ISL:'IS', ISR:'IL', ITA:'IT', JAM:'JM', JEY:'JE', JOR:'JO', JPN:'JP', KAZ:'KZ', KEN:'KE', KGZ:'KG', KHM:'KH', KIR:'KI', KNA:'KN', KOR:'KR', KWT:'KW', LAO:'LA', LBN:'LB', LBR:'LR', LBY:'LY', LCA:'LC', LIE:'LI', LKA:'LK', LSO:'LS', LTU:'LT', LUX:'LU', LVA:'LV', MAC:'MO', MAF:'MF', MAR:'MA', MCO:'MC', MDA:'MD', MDG:'MG', MDV:'MV', MEX:'MX', MHL:'MH', MKD:'MK', MLI:'ML', MLT:'MT', MMR:'MM', MNE:'ME', MNG:'MN', MNP:'MP', MOZ:'MZ', MRT:'MR', MSR:'MS', MTQ:'MQ', MUS:'MU', MWI:'MW', MYS:'MY', MYT:'YT', NAM:'NA', NCL:'NC', NER:'NE', NFK:'NF', NGA:'NG', NIC:'NI', NIU:'NU', NLD:'NL', NOR:'NO', NPL:'NP', NRU:'NR', NZL:'NZ', OMN:'OM', PAK:'PK', PAN:'PA', PCN:'PN', PER:'PE', PHL:'PH', PLW:'PW', PNG:'PG', POL:'PL', PRI:'PR', PRK:'KP', PRT:'PT', PRY:'PY', PSE:'PS', PYF:'PF', QAT:'QA', REU:'RE', ROU:'RO', RUS:'RU', RWA:'RW', SAU:'SA', SDN:'SD', SEN:'SN', SGP:'SG', SGS:'GS', SHN:'SH', SJM:'SJ', SLB:'SB', SLE:'SL', SLV:'SV', SMR:'SM', SOM:'SO', SPM:'PM', SRB:'RS', SSD:'SS', STP:'ST', SUR:'SR', SVK:'SK', SVN:'SI', SWE:'SE', SWZ:'SZ', SXM:'SX', SYC:'SC', SYR:'SY', TCA:'TC', TCD:'TD', TGO:'TG', THA:'TH', TJK:'TJ', TKL:'TK', TKM:'TM', TLS:'TL', TON:'TO', TTO:'TT', TUN:'TN', TUR:'TR', TUV:'TV', TWN:'TW', TZA:'TZ', UGA:'UG', UKR:'UA', URY:'UY', USA:'US', UZB:'UZ', VAT:'VA', VCT:'VC', VEN:'VE', VGB:'VG', VIR:'VI', VNM:'VN', VUT:'VU', WLF:'WF', WSM:'WS', YEM:'YE', ZAF:'ZA', ZMB:'ZM', ZWE:'ZW', KOS:'XK'
};

function idFor(feature) {
  const p = feature.properties ?? {};
  const candidates = [p.ISO_A2, p.ISO_A2_EH].filter((value) =>
    typeof value === 'string' && /^[A-Z]{2}$/.test(value),
  );
  let id = candidates[0];
  if (!id && p.ADM0_A3) id = alpha2ByA3[p.ADM0_A3];
  if (!id || !/^[A-Z]{2}$/.test(id)) {
    throw new Error(`Country without ISO id: ${JSON.stringify(p)}`);
  }
  return id;
}

function countryName(feature, id) {
  const p = feature.properties ?? {};
  return overrides[id] || p.NAME_PT || p.NAME_EN || p.NAME || id;
}

function admin1CountryId(feature) {
  const p = feature.properties ?? {};
  const candidates = [p.ISO_A2, p.ISO_A2_EH, p.iso_a2, p.ADM0_A3]
    .filter((value) => typeof value === 'string');
  for (const candidate of candidates) {
    const value = candidate.length === 3 ? alpha2ByA3[candidate.toUpperCase()] : candidate.toUpperCase();
    if (value && /^[A-Z]{2}$/.test(value)) return value;
  }
  return null;
}

function admin1Id(feature, countryId) {
  const p = feature.properties ?? {};
  if (countryId === 'CO' && String(p.name ?? p.NAME ?? '').toLowerCase() === 'bogota') return 'CO-DC';
  if (countryId === 'PE' && String(p.name ?? p.NAME ?? '').toLowerCase() === 'lima province') return 'PE-LMA';
  const rawIso = p.iso_3166_2 ?? p.ISO_3166_2;
  if (typeof rawIso === 'string' && rawIso.includes('~')) return null;
  if (typeof rawIso === 'string' && new RegExp(`^${countryId}-[A-Z0-9]+$`).test(rawIso.toUpperCase())) {
    return rawIso.toUpperCase();
  }
  const rawCode = p.postal ?? p.POSTAL ?? p.code_local ?? p.CODE_LOCAL ?? p.code_hasc?.split('-').pop();
  const code = String(rawCode ?? '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (!code || code.startsWith('X')) return null;
  return `${countryId}-${code}`;
}

function admin1Name(feature, id) {
  const p = feature.properties ?? {};
  return p.name_pt || p.NAME_PT || p.name_en || p.NAME_EN || p.name || p.NAME || id;
}

function featureFor(feature, id, name) {
  return { type: 'Feature', properties: { id, name }, geometry: feature.geometry };
}

function makeCollection(features) {
  return { type: 'FeatureCollection', features };
}

function pointsFromGeometry(geometry) {
  return featureParts({ geometry }).flatMap((part) => part.flatMap((ring) => ring.map((p) => [p[0], p[1]])));
}

function projectCommand(proj, input, output) {
  return `-i ${quote(input)} -proj ${proj} -o format=geojson ${quote(output)}`;
}

async function projectAndNormalize(collection, mapConfig) {
  const raw = path.join(cacheDir, `${mapConfig.id}-input.json`);
  const projected = path.join(cacheDir, `${mapConfig.id}-projected.json`);
  const normalized = path.join(cacheDir, `${mapConfig.id}-normalized.json`);
  const simplified = path.join(cacheDir, `${mapConfig.id}-simplified.json`);
  fs.writeFileSync(raw, JSON.stringify(collection));
  await runMapshaper(projectCommand(mapConfig.proj, raw, projected));
  const geo = JSON.parse(fs.readFileSync(projected, 'utf8'));
  const all = geo.features.flatMap((feature) => pointsFromGeometry(feature.geometry));
  let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
  for (const [x, y] of all) { minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y); }
  const computedBounds = { minX, minY, maxX, maxY };
  const bounds = mapConfig.normalizationBounds ?? normalizationBoundsByProjection.get(mapConfig.proj) ?? computedBounds;
  if (mapConfig.captureNormalizationBounds) {
    normalizationBoundsByProjection.set(mapConfig.proj, computedBounds);
    mapConfig.normalizationBounds = computedBounds;
  }
  ({ minX, minY, maxX, maxY } = bounds);
  const padding = 12;
  const sx = (mapConfig.width - padding * 2) / (maxX - minX);
  const sy = (mapConfig.height - padding * 2) / (maxY - minY);
  const factor = Math.min(sx, sy);
  const offsetX = (mapConfig.width - (maxX - minX) * factor) / 2;
  const offsetY = (mapConfig.height - (maxY - minY) * factor) / 2;
  // Projections use Y increasing northward; Flutter's canvas uses Y increasing
  // downward. Flipping here also flips every ring consistently, preserving
  // the relative winding of outer rings and holes for non-zero filling.
  const transformPoint = ([x, y]) => [
    (x - minX) * factor + offsetX,
    (maxY - y) * factor + offsetY,
  ];
  for (const feature of geo.features) {
    for (const part of featureParts(feature)) for (const ring of part) for (let i = 0; i < ring.length; i++) ring[i] = transformPoint(ring[i]);
  }
  fs.writeFileSync(normalized, JSON.stringify(geo));
  await runMapshaper(
    `-i ${quote(normalized)} -simplify interval=${mapConfig.simplifyTolerance} keep-shapes -o format=geojson ${quote(simplified)}`,
  );
  const result = JSON.parse(fs.readFileSync(simplified, 'utf8'));
  const originalById = new Map(geo.features.map((feature) => [feature.properties?.id, feature]));
  for (const feature of result.features) {
    if (polygonRings(feature, 0.25).length === 0) {
      const original = originalById.get(feature.properties?.id);
      if (original) feature.geometry = original.geometry;
    }
  }
  return result;
}

function polygonRings(feature, scale) {
  const rings = [];
  for (const part of featureParts(feature)) for (const ring of part) {
    const result = [];
    for (const point of ring) {
      const x = Math.round(point[0] / scale); const y = Math.round(point[1] / scale);
      if (!result.length || result[result.length - 2] !== x || result[result.length - 1] !== y) result.push(x, y);
    }
    if (result.length >= 6 && result[0] === result[result.length - 2] && result[1] === result[result.length - 1]) result.splice(result.length - 2, 2);
    if (result.length >= 6) rings.push(result);
  }
  return rings;
}

function inside(point, rings) {
  let result = false;
  for (const ring of rings) {
    for (let i = 0, j = ring.length - 2; i < ring.length; i += 2) {
      const xi = ring[i], yi = ring[i + 1], xj = ring[j], yj = ring[j + 1];
      if ((yi > point[1]) !== (yj > point[1]) && point[0] < (xj - xi) * (point[1] - yi) / (yj - yi) + xi) result = !result;
      j = i;
    }
  }
  return result;
}

function anchorFor(rings, scale) {
  const polygons = rings.map((ring) => ring.reduce((points, value, i) => { if (i % 2 === 0) points.push([value * scale, ring[i + 1] * scale]); return points; }, []));
  const largest = polygons.reduce((a, b) => Math.abs(area(b)) > Math.abs(area(a)) ? b : a, polygons[0]);
  const candidate = polylabel([largest], 0.25);
  const quantized = [Math.round(candidate[0] / scale), Math.round(candidate[1] / scale)];
  if (inside(quantized, rings)) return quantized;
  return [Math.round(largest[0][0] / scale), Math.round(largest[0][1] / scale)];
}

function area(ring) { let sum = 0; for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) sum += ring[j][0] * ring[i][1] - ring[i][0] * ring[j][1]; return sum / 2; }

function vertexKey(point) { return `${point[0]},${point[1]}`; }

function chainEdges(edges) {
  const adjacency = new Map();
  const add = (vertex, index) => {
    const list = adjacency.get(vertex) ?? [];
    list.push(index);
    adjacency.set(vertex, list);
  };
  for (let i = 0; i < edges.length; i++) {
    add(vertexKey(edges[i].a), i);
    add(vertexKey(edges[i].b), i);
  }
  const degree = (vertex) => adjacency.get(vertex)?.length ?? 0;
  const used = new Set();
  const lines = [];
  for (let i = 0; i < edges.length; i++) {
    if (used.has(i)) continue;
    const edge = edges[i];
    const aKey = vertexKey(edge.a);
    const bKey = vertexKey(edge.b);
    const start = degree(aKey) !== 2 ? edge.a : edge.b;
    const line = [start];
    let current = start;
    let edgeIndex = i;
    while (edgeIndex != null && !used.has(edgeIndex)) {
      used.add(edgeIndex);
      const currentEdge = edges[edgeIndex];
      const currentKey = vertexKey(current);
      const next = vertexKey(currentEdge.a) === currentKey ? currentEdge.b : currentEdge.a;
      line.push(next);
      current = next;
      if (degree(vertexKey(current)) !== 2) break;
      const nextEdge = (adjacency.get(vertexKey(current)) ?? []).find((index) => !used.has(index));
      edgeIndex = nextEdge;
    }
    if (line.length >= 2) lines.push(line.flatMap((point) => point));
  }
  return lines;
}

function sharedLines(regions) {
  const edges = new Map();
  for (const region of regions) for (const ring of region.rings) {
    for (let i = 0; i < ring.length; i += 2) {
      const next = (i + 2) % ring.length;
      const a = [ring[i], ring[i + 1]];
      const b = [ring[next], ring[next + 1]];
      const aKey = vertexKey(a);
      const bKey = vertexKey(b);
      const key = aKey < bKey ? `${aKey}|${bKey}` : `${bKey}|${aKey}`;
      const existing = edges.get(key);
      if (existing) existing.count++; else edges.set(key, { a, b, count: 1 });
    }
  }
  const allEdges = [...edges.values()];
  const innerEdges = allEdges.filter((edge) => edge.count === 2);
  const outlineEdges = allEdges.filter((edge) => edge.count === 1);
  // A pair of almost-identical exterior edges indicates that neighboring
  // features were simplified independently instead of sharing topology.
  const close = (a, b) => Math.hypot((a[0] - b[0]) * 0.25, (a[1] - b[1]) * 0.25) < 0.5;
  const nearlyShared = outlineEdges.filter((edge, index) => outlineEdges.some((other, otherIndex) => {
    if (index === otherIndex) return false;
    return (close(edge.a, other.a) && close(edge.b, other.b)) ||
      (close(edge.a, other.b) && close(edge.b, other.a));
  })).length;
  return {
    inner: chainEdges(innerEdges),
    outline: chainEdges(outlineEdges),
    nearlyShared,
    edgeCounts: { inner: innerEdges.length, outline: outlineEdges.length },
  };
}

function stringTable(map) {
  const values = new Set();
  for (const region of map.regions) { values.add(region.id); values.add(region.name); }
  const list = [...values]; const indices = new Map(list.map((value, index) => [value, index]));
  return { list, indices };
}

function zigzag(value) { return value < 0 ? (-value * 2 - 1) : value * 2; }
function varint(value) {
  const bytes = [];
  do {
    let byte = value & 0x7f;
    value >>>= 7;
    if (value) byte |= 0x80;
    bytes.push(byte);
  } while (value);
  return bytes;
}
function unsignedVarint(value) {
  const bytes = [];
  do {
    let byte = value & 0x7f;
    value >>>= 7;
    if (value) byte |= 0x80;
    bytes.push(byte);
  } while (value);
  return bytes;
}
function writeLine(out, line) {
  out.push(...unsignedVarint(line.length / 2));
  let px = 0; let py = 0;
  for (let i = 0; i < line.length; i += 2) {
    out.push(...varint(zigzag(line[i] - px)), ...varint(zigzag(line[i + 1] - py)));
    px = line[i]; py = line[i + 1];
  }
}

function encode(map) {
  const { list, indices } = stringTable(map);
  const flags = (map.inner.length ? 1 : 0) | (map.outline.length ? 2 : 0);
  const header = Buffer.alloc(17); let h = 0;
  header.write('SMAP', h); h += 4;
  header.writeUInt8(2, h++);
  header.writeFloatLE(map.width, h); h += 4;
  header.writeFloatLE(map.height, h); h += 4;
  header.writeFloatLE(map.scale, h);
  const out = [...header, ...unsignedVarint(map.regions.length), flags];
  out.push(...unsignedVarint(list.length));
  for (const value of list) {
    const data = Buffer.from(value, 'utf8');
    out.push(...unsignedVarint(data.length), ...data);
  }
  for (const region of map.regions) {
    out.push(...unsignedVarint(indices.get(region.id)), ...unsignedVarint(indices.get(region.name)));
    const bbox = Buffer.alloc(16);
    bbox.writeInt32LE(region.bbox[0], 0); bbox.writeInt32LE(region.bbox[1], 4);
    bbox.writeInt32LE(region.bbox[2], 8); bbox.writeInt32LE(region.bbox[3], 12);
    out.push(...bbox);
    const anchor = Buffer.alloc(8);
    anchor.writeInt32LE(region.anchor[0], 0); anchor.writeInt32LE(region.anchor[1], 4);
    out.push(...anchor, ...unsignedVarint(region.rings.length));
    for (const ring of region.rings) writeLine(out, ring);
  }
  for (const lines of [map.inner, map.outline]) if (lines.length) {
    out.push(...unsignedVarint(lines.length));
    for (const line of lines) writeLine(out, line);
  }
  return Buffer.from(out);
}

function mapModel(geo, config) {
  const scale = 0.25;
  const regions = geo.features.map((feature) => {
    const id = feature.properties.id; const name = feature.properties.name; const rings = polygonRings(feature, scale);
    if (rings.length === 0) {
      const points = pointsFromGeometry(feature.geometry).slice(0, 3).flatMap((point) => [Math.round(point[0] / scale), Math.round(point[1] / scale)]);
      const unique = new Set();
      for (let i = 0; i + 1 < points.length; i += 2) unique.add(`${points[i]},${points[i + 1]}`);
      if (unique.size < 3) {
        const x = points[0];
        const y = points[1];
        // Preserve a visible, hittable footprint for sub-quantum countries
        // such as Vatican City instead of emitting a zero-area path.
        rings.push([x, y, x + 2, y, x + 2, y + 2, x, y + 2]);
      } else {
        rings.push(points);
      }
    }
    const coords = rings.flatMap((ring) => ring.reduce((all, value, i) => { if (i % 2 === 0) all.push([value, ring[i + 1]]); return all; }, []));
    const bbox = [Math.min(...coords.map((p) => p[0])), Math.min(...coords.map((p) => p[1])), Math.max(...coords.map((p) => p[0])), Math.max(...coords.map((p) => p[1]))];
    return { id, name, rings, bbox, anchor: anchorFor(rings, scale) };
  });
  const ids = new Set();
  for (const region of regions) {
    if (!/^[A-Z]{2}$/.test(region.id) && !/^[A-Z]{2}-[A-Z0-9]{1,3}$/.test(region.id) && !/^BR-\d{7}$/.test(region.id)) throw new Error(`${config.id}: invalid id ${region.id}`);
    if (!ids.add(region.id)) throw new Error(`${config.id}: duplicate id ${region.id}`);
    if (region.rings.isEmpty) throw new Error(`${config.id}: empty geometry for ${region.id}`);
    for (const ring of region.rings) {
      if (ring.length < 6) throw new Error(`${config.id}: invalid ring for ${region.id}`);
      for (let i = 0; i < ring.length; i += 2) {
        const next = (i + 2) % ring.length;
        if (Math.abs(ring[next] - ring[i]) * scale > config.width / 2 || Math.abs(ring[next + 1] - ring[i + 1]) * scale > config.width / 2) {
          throw new Error(`${config.id}: antimeridian-like segment in ${region.id}`);
        }
      }
    }
  }
  const lines = sharedLines(regions);
  return { id: config.id, width: config.width, height: config.height, scale, focusRegionPrefix: config.focusRegionPrefix, regions, inner: lines.inner, outline: lines.outline, nearlyShared: lines.nearlyShared, edgeCounts: lines.edgeCounts };
}

function writeAsset(map, filename) {
  const bytes = encode(map);
  fs.writeFileSync(path.join(exampleAssetsDir, filename), bytes);
  return { bytes: bytes.length, vertices: map.regions.reduce((sum, region) => sum + region.rings.reduce((n, ring) => n + ring.length / 2, 0), 0), maxRegionVertices: Math.max(...map.regions.map((r) => r.rings.reduce((n, ring) => n + ring.length / 2, 0))) };
}

function writeGenerated(map) {
  const bytes = encode(map); const base64 = bytes.toString('base64');
  const symbol = map.id.replace(/(^|_)(.)/g, (_, __, c) => c.toUpperCase());
  const target = path.join(generatedDir, `${map.id}.g.dart`);
  const publicId = map.id.replaceAll('_', '');
  fs.writeFileSync(target, `// GENERATED CODE - DO NOT MODIFY BY HAND.\nimport 'dart:convert';\nimport '../codec.dart';\nimport '../models.dart';\n\nconst String _data = '${base64}';\nMapDefinition? _cache${symbol};\n\n/// Lazily decodes the embedded ${publicId} map.\nMapDefinition get generated${symbol} => _cache${symbol} ??= decodeGenerated(\n  base64Decode(_data),\n  id: '${publicId}',${map.focusRegionPrefix ? `\n  focusRegionPrefix: '${map.focusRegionPrefix}',` : ''}\n);\n\n/// Decodes and caches the embedded ${publicId} map off the UI isolate.\nFuture<MapDefinition> preloadGenerated${symbol}() async {\n  final cached = _cache${symbol};\n  if (cached != null) return cached;\n  final decoded = await decodeGeneratedAsync(_data, id: '${publicId}',${map.focusRegionPrefix ? ` focusRegionPrefix: '${map.focusRegionPrefix}',` : ''});\n  return _cache${symbol} ??= decoded;\n}\n`);
  return { bytes: bytes.length, vertices: map.regions.reduce((sum, region) => sum + region.rings.reduce((n, ring) => n + ring.length / 2, 0), 0), maxRegionVertices: Math.max(...map.regions.map((r) => r.rings.reduce((n, ring) => n + ring.length / 2, 0))) };
}

async function main() {
  const neZip = await source('naturalEarth50mCountries');
  const statesUrl = await source('ibgeStatesIntermediate');
  const namesUrl = await source('ibgeStateNames');
  const neJsonPath = path.join(cacheDir, 'natural-earth.json');
  if (!fs.existsSync(neJsonPath)) {
    const extracted = path.join(cacheDir, 'ne-extracted'); fs.mkdirSync(extracted, { recursive: true });
    execFileSync('unzip', ['-o', neZip, '-d', extracted], { stdio: 'ignore' });
    const shp = fs.readdirSync(extracted).find((file) => file.endsWith('.shp'));
    if (!shp) throw new Error('Natural Earth zip did not contain a shapefile');
    await convertToGeoJson(path.join(extracted, shp), neJsonPath);
  }
  const ne = JSON.parse(fs.readFileSync(neJsonPath, 'utf8'));
  const admin1Zip = await source('naturalEarth10mAdmin1');
  const admin1JsonPath = path.join(cacheDir, 'natural-earth-admin1.json');
  if (!fs.existsSync(admin1JsonPath)) {
    const extracted = path.join(cacheDir, 'admin1-extracted'); fs.mkdirSync(extracted, { recursive: true });
    execFileSync('unzip', ['-o', admin1Zip, '-d', extracted], { stdio: 'ignore' });
    const shp = fs.readdirSync(extracted).find((file) => file.endsWith('.shp'));
    if (!shp) throw new Error('Natural Earth admin-1 zip did not contain a shapefile');
    await convertToGeoJson(path.join(extracted, shp), admin1JsonPath);
  }
  const admin1 = JSON.parse(fs.readFileSync(admin1JsonPath, 'utf8'));
  const countries = []; let france;
  const excludedDisputedA3 = new Set(['SOL', 'CYN']);
  for (const feature of ne.features) {
    if (excludedDisputedA3.has(feature.properties?.ADM0_A3)) continue; // represented by sovereign feature
    const properties = feature.properties ?? {};
    if (properties.TYPE === 'Indeterminate') continue;
    const id = idFor(feature);
    if (id === 'FR') france = feature;
    if (countries.some((item) => item.id === id)) continue;
    countries.push({ feature, id, name: countryName(feature, id) });
  }
  if (!france) throw new Error('Natural Earth France feature not found');
  const gfParts = extractFrenchGuiana(france);
  const franceWithoutGf = withoutFrenchGuiana(france);
  const gf = { type: 'Feature', properties: { id: 'GF', name: overrides.GF }, geometry: { type: gfParts.length === 1 ? 'Polygon' : 'MultiPolygon', coordinates: gfParts.length === 1 ? gfParts[0] : gfParts } };
  const southIds = new Set(['AR','BO','BR','CL','CO','EC','GF','GY','PE','PY','SR','UY','VE']);
  const latinIds = new Set(['AR','BO','BR','CL','CO','EC','GF','GY','PE','PY','SR','UY','VE','MX','BZ','CR','SV','GT','HN','NI','PA','AG','BS','BB','CU','DM','DO','GD','HT','JM','KN','LC','VC','TT']);
  const buildFeatures = (ids, includeGf) => countries.filter((item) => ids.has(item.id)).map((item) => featureFor(item.id === 'FR' ? franceWithoutGf : item.feature, item.id, item.name)).concat(includeGf ? [gf] : []);
  const southConfig = { id: 'south_america', width: 820, height: 1040, proj: '+proj=aea +lat_1=-5 +lat_2=-42 +lon_0=-60', simplifyTolerance: 0.6, captureNormalizationBounds: true, features: buildFeatures(southIds, true) };
  const configs = [
    { id: 'world', width: 1200, height: 620, proj: '+proj=eqearth', simplifyTolerance: 0.6, features: countries.filter((item) => item.id !== 'AQ').map((item) => featureFor(item.id === 'FR' ? france : item.feature, item.id, item.name)) },
    { id: 'latin_america', width: 1100, height: 780, proj: '+proj=lcc +lat_1=10 +lat_2=-25 +lon_0=-65', simplifyTolerance: 0.6, features: buildFeatures(latinIds, true) },
    southConfig,
  ];
  const stateData = JSON.parse(fs.readFileSync(statesUrl, 'utf8'));
  const stateNames = JSON.parse(fs.readFileSync(namesUrl, 'utf8'));
  const municipalitiesUrl = await source('ibgeMunicipalitiesIntermediate');
  const municipalityNamesUrl = await source('ibgeMunicipalityNames');
  const municipalityData = JSON.parse(fs.readFileSync(municipalitiesUrl, 'utf8'));
  const municipalityNames = JSON.parse(fs.readFileSync(municipalityNamesUrl, 'utf8'));
  const municipalityNameByCode = new Map(municipalityNames.map((item) => [String(item.id).padStart(7, '0'), item.nome]));
  const names = new Map(stateNames.map((state) => [String(state.sigla).toUpperCase(), state.nome]));
  const ibgeCodes = { '11':'RO', '12':'AC', '13':'AM', '14':'RR', '15':'PA', '16':'AP', '17':'TO', '21':'MA', '22':'PI', '23':'CE', '24':'RN', '25':'PB', '26':'PE', '27':'AL', '28':'SE', '29':'BA', '31':'MG', '32':'ES', '33':'RJ', '35':'SP', '41':'PR', '42':'SC', '43':'RS', '50':'MS', '51':'MT', '52':'GO', '53':'DF' };
  const stateFeatures = stateData.features.map((feature) => { const p = feature.properties ?? {}; const sigla = String(p.sigla ?? p.SIGLA ?? p.abbrev ?? ibgeCodes[String(p.codarea)] ?? '').toUpperCase(); const name = names.get(sigla) ?? p.nome ?? p.NM_UF; if (!/^[A-Z]{2}$/.test(sigla)) throw new Error(`IBGE UF without sigla: ${JSON.stringify(p)}`); return featureFor(feature, `BR-${sigla}`, name); });
  const admin1Countries = new Set(['AR', 'BO', 'CL', 'CO', 'EC', 'GY', 'PE', 'PY', 'SR', 'UY', 'VE']);
  const admin1FeaturesByCountry = new Map();
  for (const feature of admin1.features) {
    const countryId = admin1CountryId(feature);
    if (!countryId || !admin1Countries.has(countryId)) continue;
    const id = admin1Id(feature, countryId);
    if (!id) continue;
    const list = admin1FeaturesByCountry.get(countryId) ?? [];
    list.push(featureFor(feature, id, admin1Name(feature, id)));
    admin1FeaturesByCountry.set(countryId, list);
  }
  const expectedAdmin1Counts = { AR: 24, BO: 9, CL: 16, CO: 33, EC: 24, GY: 10, PE: 26, PY: 18, SR: 10, UY: 19, VE: 25 };
  for (const [countryId, expected] of Object.entries(expectedAdmin1Counts)) {
    const features = admin1FeaturesByCountry.get(countryId) ?? [];
    const ids = new Set(features.map((feature) => feature.properties.id));
    if (features.length !== expected || ids.size !== expected) {
      throw new Error(`Natural Earth admin-1 ${countryId}: expected ${expected} unique regions, got ${features.length}`);
    }
  }
  const contextFeatures = buildFeatures(southIds, true);
  const focusCountries = ['AR', 'BO', 'BR', 'CL', 'CO', 'EC', 'GY', 'PE', 'PY', 'SR', 'UY', 'VE'];
  for (const countryId of focusCountries) {
    const selected = countryId === 'BR' ? stateFeatures : admin1FeaturesByCountry.get(countryId);
    if (!selected || selected.length === 0) throw new Error(`Missing focus regions for ${countryId}`);
    configs.push({
      id: `south_america_focus_${countryId.toLowerCase()}`,
      width: southConfig.width,
      height: southConfig.height,
      proj: southConfig.proj,
      normalizationBounds: southConfig.normalizationBounds,
      simplifyTolerance: 0.6,
      focusRegionPrefix: `${countryId}-`,
      features: contextFeatures.filter((feature) => feature.properties.id !== countryId).concat(selected),
    });
  }
  configs.push({ id: 'brazil_states', width: 900, height: 1000, proj: '+proj=aea +lat_1=-2 +lat_2=-22 +lon_0=-54', simplifyTolerance: 0.6, features: stateFeatures });
  const municipalityFeatures = municipalityData.features.map((feature) => {
    const p = feature.properties ?? {};
    const rawCode = p.codarea ?? p.codigo_ibge ?? p.CD_MUN ?? p.code ?? p.id;
    const code = String(rawCode ?? '').replace(/\D/g, '').padStart(7, '0');
    if (!/^\d{7}$/.test(code)) throw new Error(`IBGE municipality without 7-digit code: ${JSON.stringify(p)}`);
    const name = municipalityNameByCode.get(code) ?? p.nome ?? p.NM_MUN;
    if (!name) throw new Error(`Missing municipality name for ${code}`);
    return featureFor(feature, `BR-${code}`, name);
  });
  if (municipalityFeatures.length !== 5570) throw new Error(`Expected 5570 municipalities, got ${municipalityFeatures.length}`);
  configs.push({ id: 'brazil_municipalities', width: 900, height: 1000, proj: '+proj=aea +lat_1=-2 +lat_2=-22 +lon_0=-54', simplifyTolerance: 0.4, features: municipalityFeatures, asset: 'brazil_municipalities.smap' });
  const report = { format: 'SMAP v2', maps: {} };
  const focusExpectedRegions = {
    south_america_focus_ar: 36,
    south_america_focus_bo: 21,
    south_america_focus_br: 39,
    south_america_focus_cl: 28,
    south_america_focus_co: 45,
    south_america_focus_ec: 36,
    south_america_focus_gy: 22,
    south_america_focus_pe: 38,
    south_america_focus_py: 30,
    south_america_focus_sr: 22,
    south_america_focus_uy: 31,
    south_america_focus_ve: 37,
  };
  for (const config of configs) {
    const geo = await projectAndNormalize(makeCollection(config.features), config);
    const model = mapModel(geo, config);
    const expected = { world: 170, latin_america: 34, south_america: 13, brazil_states: 27, brazil_municipalities: 5570, ...focusExpectedRegions }[config.id];
    if (model.regions.length !== expected && config.id !== 'world') throw new Error(`${config.id}: expected ${expected} regions, got ${model.regions.length}`);
    if (config.id === 'brazil_municipalities') {
      const prefixes = new Set(model.regions.map((region) => region.id.slice(3, 5)));
      const expectedUfPrefixes = new Set(['11','12','13','14','15','16','17','21','22','23','24','25','26','27','28','29','31','32','33','35','41','42','43','50','51','52','53']);
      for (const prefix of expectedUfPrefixes) if (!prefixes.has(prefix)) throw new Error(`Missing municipalities for UF code ${prefix}`);
    }
    const limit = { world: 40000, latin_america: 20000, south_america: 12000, brazil_states: 12000, brazil_municipalities: 300000, ...Object.fromEntries(Object.keys(focusExpectedRegions).map((id) => [id, 30000])) }[config.id];
    const stats = config.asset ? writeAsset(model, config.asset) : writeGenerated(model);
    if (stats.vertices > limit) throw new Error(`${config.id}: ${stats.vertices} vertices exceed ${limit}`);
    report.maps[config.id] = {
      regions: model.regions.length,
      vertices: stats.vertices,
      bytes: stats.bytes,
      maxRegionVertices: stats.maxRegionVertices,
      viewBox: [config.width, config.height],
      quantizationScale: model.scale,
      simplificationTolerance: config.simplifyTolerance,
      estimatedMaxError: config.simplifyTolerance,
      innerBorders: model.inner.length,
      outlinePolylines: model.outline.length,
      innerEdges: model.edgeCounts.inner,
      outlineEdges: model.edgeCounts.outline,
      nearlySharedEdges: model.nearlyShared,
      ...(config.asset ? { asset: `example/assets/maps/${config.asset}`, assetBytes: stats.bytes } : {}),
    };
  }
  fs.writeFileSync(path.join(here, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(path.join(root, 'ATTRIBUTION.md'), `# Map data attribution\n\n- Natural Earth 50m admin-0 cultural (manifest date 2025-02-01): public domain, downloaded from https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip.\n- Natural Earth 10m admin-1 states and provinces (manifest date 2025-02-01): public domain, SHA-256 `efc59726337323058f9446210adc96673179cd344e053666ee3d28cb58ba2b05`, downloaded from https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_1_states_provinces.zip. These focus layers contain admin-1 regions only; they never contain cities or municipalities.\n- IBGE UFs (manifest date 2025-02-01): https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&intrarregiao=UF&qualidade=intermediaria, intermediate quality; names from https://servicodados.ibge.gov.br/api/v1/localidades/estados. The geometry was simplified with a 0.6 view-box-unit tolerance, topology-preserving keep-shapes, and quantized to a 0.25 view-box-unit grid.\n- IBGE municipalities (manifest date 2025-02-01): https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&intrarregiao=municipio&qualidade=intermediaria, intermediate quality; names from https://servicodados.ibge.gov.br/api/v1/localidades/municipios. Simplified and quantized like the UFs; distributed only as the optional example asset example/assets/maps/brazil_municipalities.smap, not inside lib/.\n- Source credit: \"Fonte: IBGE\" must accompany apps that display the Brazilian layers. Confirm the current IBGE terms of use before commercial distribution.\n- Build tools: mapshaper 0.7.98 (MIT), polylabel 2.1.0 (ISC). They are build-only dependencies; the Flutter package has no runtime dependency.\n\nKosovo is retained as XK when present. Somaliland, Northern Cyprus and other unrecognized disputed fragments are omitted in favor of their sovereign feature; Antarctica is excluded. French Guiana is merged into FR for the world map and retained as GF in regional maps.\n`);
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => { console.error(error.stack || error); process.exitCode = 1; });
