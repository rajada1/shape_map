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
const packageAssetsDir = path.join(root, 'assets/maps/country_focus');
const packageCatalogDir = path.join(root, 'assets/catalog');
const catalogDir = path.join(root, 'catalog');
fs.mkdirSync(cacheDir, { recursive: true });
fs.mkdirSync(generatedDir, { recursive: true });
fs.mkdirSync(exampleAssetsDir, { recursive: true });
fs.mkdirSync(packageAssetsDir, { recursive: true });
fs.mkdirSync(packageCatalogDir, { recursive: true });
fs.mkdirSync(catalogDir, { recursive: true });

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

function nonEmpty(value) {
  return value != null && typeof value === 'string' && value.trim() !== '' && !['-99', 'undefined', 'null'].includes(value.trim().toLowerCase());
}

function admin1SourceCodes(feature) {
  const p = feature.properties ?? {};
  return [p.iso_3166_2, p.ISO_3166_2, p.code_hasc, p.postal, p.code_local, p.fips, p.adm1_code, p.gn_a1_code, p.gn_id]
    .filter((value) => nonEmpty(String(value)))
    .map((value) => String(value).trim());
}

function admin1Aliases(feature, countryId, id, blockedAliases = new Set()) {
  const p = feature.properties ?? {};
  const aliases = new Set([id]);
  const add = (value) => {
    if (!nonEmpty(String(value))) return;
    const raw = String(value).trim().toUpperCase();
    if (raw === id) {
      aliases.add(raw);
      return;
    }
    const normalized = raw.replaceAll('.', '-');
    if (normalized.startsWith(`${countryId}-`)) {
      if (/^[A-Z]{2}-[A-Z0-9]{1,3}$/.test(normalized)) aliases.add(normalized);
      return;
    }
    const suffix = raw.replace(/[^A-Z0-9]/g, '');
    if (suffix && !suffix.startsWith('X') && /^[A-Z]{2}-[A-Z0-9]{1,3}$/.test(`${countryId}-${suffix}`)) aliases.add(`${countryId}-${suffix}`);
  };
  for (const value of [p.iso_3166_2, p.ISO_3166_2, p.gn_a1_code]) add(value);
  const geoNamesCode = String(p.gn_a1_code ?? '').trim().toUpperCase();
  if (geoNamesCode.includes('.')) add(`${countryId}-${geoNamesCode.split('.').pop()}`);
  return [...aliases]
    .filter((value) => value.length > 0 && !blockedAliases.has(value))
    .sort();
}

function countryNameFields(feature, id) {
  const p = feature.properties ?? {};
  return {
    name_en: p.NAME_EN || p.name_en || p.NAME || p.name || id,
    name_pt: overrides[id] || p.NAME_PT || p.name_pt || p.NAME_EN || p.name_en || p.NAME || id,
    name_es: p.NAME_ES || p.name_es || p.NAME_EN || p.name_en || p.NAME || id,
  };
}

const ALLOWED_REGIONS = new Set([
  'south_america',
  'central_america',
  'caribbean',
  'north_america',
  'europe',
  'asia',
  'africa',
  'oceania',
]);

const COUNTRY_REGION_OVERRIDES = {
  // Natural Earth's continent fields are unavailable for these territories.
  GS: 'south_america',
  IO: 'asia',
  SH: 'africa',
  SC: 'africa',
  MU: 'africa',
  MV: 'asia',
  TF: 'africa',
  HM: 'oceania',
};

const COUNTRY_ISO3_OVERRIDES = {
  FR: 'FRA',
  NO: 'NOR',
  XK: 'XKX',
};

function countryIso3(feature, id) {
  const p = feature.properties ?? {};
  return COUNTRY_ISO3_OVERRIDES[id] || p.ISO_A3 || p.ISO_A3_EH || p.ADM0_A3 || id;
}

// Duplicate source ISO 3166-2 values represent separate admin-1 features in
// Natural Earth. Prefer a unique short source suffix; otherwise this stable
// three-character base36 hash keeps the generated ID within the catalog regex.
function sourceIdentity(feature) {
  const p = feature.properties ?? {};
  const stable = [p.adm1_code, p.gn_id, p.gn_a1_code, p.iso_3166_2, p.name, p.NAME]
    .map((value) => String(value ?? '').trim())
    .find((value) => nonEmpty(value));
  if (stable) return stable;
  return crypto.createHash('sha256').update(JSON.stringify(feature.geometry ?? null)).digest('hex');
}

const ISO_3166_2_NAMES = new Map([
  ['AU-NSW', ['New South Wales']],
  // ISO lists KZ-ALA for Almaty city and KZ-ALM for Almaty Region.
  ['KZ-ALA', ['Almaty City']],
  ['PH-MNL', ['Metro Manila']],
  ['RU-KR', ['Karelia']],
]);

// Natural Earth carries the historical GeoNames code KZ.01 for the region,
// while ISO 3166-2 uses KZ-ALM. This source-specific mapping is only used when
// the duplicate KZ-ALA code is split; it is not a general code invention rule.
const KNOWN_ALTERNATE_ISO_CODES = new Map([
  ['KAZ-3207', 'KZ-ALM'],
]);

function normalizedName(value) {
  return String(value ?? '').trim().toLowerCase().replace(/[.']/g, '').replace(/\\s+/g, ' ');
}

function sourceIsoValues(feature) {
  const p = feature.properties ?? {};
  return [p.iso_3166_2, p.ISO_3166_2].filter((value) => nonEmpty(String(value))).map((value) => String(value).trim().toUpperCase().replaceAll('.', '-'));
}

function hasFallbackIsoCode(feature) {
  return sourceIsoValues(feature).some((value) => value.includes('~') || value.startsWith('-99'));
}

function hasCanonicalIsoCode(feature, baseId) {
  return sourceIsoValues(feature).includes(baseId) && !hasFallbackIsoCode(feature);
}

function matchesKnownIsoName(feature, baseId) {
  const names = ISO_3166_2_NAMES.get(baseId) ?? [];
  if (names.length === 0) return false;
  const p = feature.properties ?? {};
  const featureNames = [p.name, p.NAME, p.name_en, p.NAME_EN, p.name_local, p.NAME_LOCAL].map(normalizedName);
  return names.some((name) => featureNames.includes(normalizedName(name)));
}

function geometryArea(feature) {
  return featureParts(feature).reduce((total, part) => total + Math.abs(part.reduce((sum, ring) => {
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) sum += ring[j][0] * ring[i][1] - ring[i][0] * ring[j][1];
    return sum;
  }, 0) / 2), 0);
}

function chooseAdmin1Owner(group, baseId) {
  return [...group].sort((left, right) => {
    const canonicalIso = Number(hasCanonicalIsoCode(right.feature, baseId)) - Number(hasCanonicalIsoCode(left.feature, baseId));
    if (canonicalIso !== 0) return canonicalIso;
    const knownName = Number(matchesKnownIsoName(right.feature, baseId)) - Number(matchesKnownIsoName(left.feature, baseId));
    if (knownName !== 0) return knownName;
    const area = geometryArea(right.feature) - geometryArea(left.feature);
    if (area !== 0) return area;
    return sourceIdentity(left.feature).localeCompare(sourceIdentity(right.feature));
  })[0];
}

function candidateSuffixes(feature, countryId, baseId) {
  const p = feature.properties ?? {};
  const suffixes = new Set();
  const add = (value) => {
    if (!nonEmpty(String(value))) return;
    const normalized = String(value).trim().toUpperCase().replaceAll('.', '-');
    const suffix = normalized.includes('-') ? normalized.split('-').pop() : normalized;
    if (/^[A-Z0-9]{1,3}$/.test(suffix) && `${countryId}-${suffix}` !== baseId) suffixes.add(suffix);
  };
  // ISO-like values come first, then short source identifiers. The admin code
  // tail prevents hash allocation for records whose source has a stable key.
  for (const value of [p.iso_3166_2, p.ISO_3166_2, p.code_hasc, p.postal, p.POSTAL, p.code_local, p.CODE_LOCAL, p.fips, p.gn_a1_code, p.adm1_code, p.diss_me, p.sub_code]) add(value);
  return [...suffixes];
}

function alternateIsoCode(entry) {
  const sourceCode = String(entry.feature.properties?.adm1_code ?? '').trim();
  return KNOWN_ALTERNATE_ISO_CODES.get(sourceCode) ?? null;
}

function hashSuffix(countryId, baseId, feature, attempt) {
  const input = `${countryId}|${baseId}|${sourceIdentity(feature)}|${attempt}`;
  const digest = crypto.createHash('sha256').update(input).digest('hex');
  return parseInt(digest.slice(0, 8), 16).toString(36).toUpperCase().padStart(3, '0').slice(-3);
}

function resolveAdmin1Ids(entries, countryId) {
  const grouped = new Map();
  for (const entry of entries) {
    const group = grouped.get(entry.id) ?? [];
    group.push(entry);
    grouped.set(entry.id, group);
  }
  const ambiguousCodes = new Set([...grouped].filter(([, group]) => group.length > 1).map(([id]) => id));
  const resolutions = [];
  const used = new Set(entries.map((entry) => entry.id));
  for (const [baseId, group] of grouped) {
    if (group.length === 1) continue;
    const owner = chooseAdmin1Owner(group, baseId);
    const secondary = group.filter((entry) => entry !== owner)
      .sort((left, right) => sourceIdentity(left.feature).localeCompare(sourceIdentity(right.feature)));
    const assignments = [];
    for (const entry of secondary) {
      const explicit = alternateIsoCode(entry);
      let assignedId = explicit && !used.has(explicit) && explicit.startsWith(`${countryId}-`) ? explicit : null;
      let rule = assignedId ? 'alternate_iso_3166_2' : null;
      if (!assignedId) {
        const suffix = candidateSuffixes(entry.feature, countryId, baseId)
          .find((value) => !used.has(`${countryId}-${value}`));
        if (suffix) {
          assignedId = `${countryId}-${suffix}`;
          rule = 'source_suffix';
        }
      }
      let attempt = 0;
      while (!assignedId || used.has(assignedId)) {
        assignedId = `${countryId}-${hashSuffix(countryId, baseId, entry.feature, attempt++)}`;
        rule = 'stable_hash_fallback';
      }
      entry.id = assignedId;
      used.add(assignedId);
      assignments.push({
        source: sourceIdentity(entry.feature),
        name: admin1Name(entry.feature, baseId),
        code: assignedId,
        rule,
      });
    }
    resolutions.push({
      country: countryId,
      originalCode: baseId,
      owner: { source: sourceIdentity(owner.feature), name: admin1Name(owner.feature, baseId), code: baseId },
      secondary: assignments,
    });
  }
  return { ambiguousCodes, resolutions };
}

function dissolveAnnexedSmallIslands(entries, countryId) {
  const grouped = new Map();
  for (const entry of entries) {
    const group = grouped.get(entry.id) ?? [];
    group.push(entry);
    grouped.set(entry.id, group);
  }
  const dissolved = [];
  const ambiguousCodes = new Set([...grouped].filter(([, group]) => group.length > 1).map(([id]) => id));
  const retained = [];
  for (const [baseId, group] of grouped) {
    const owner = group.length > 1 ? chooseAdmin1Owner(group, baseId) : null;
    const ownerArea = owner ? geometryArea(owner.feature) : 0;
    for (const entry of group) {
      const p = entry.feature.properties ?? {};
      const name = normalizedName(p.name ?? p.NAME ?? p.name_en ?? p.NAME_EN);
      const type = normalizedName(p.type ?? p.TYPE ?? p.type_en ?? p.TYPE_EN);
      const isSmallAnnexedIsland = entry !== owner && ownerArea > 0 && geometryArea(entry.feature) / ownerArea <= 0.05 && (type.includes('territory') || name.includes('island'));
      if (!isSmallAnnexedIsland) {
        retained.push(entry);
        continue;
      }
      const ownerParts = featureParts(owner.feature);
      const annexedParts = featureParts(entry.feature);
      owner.feature = {
        ...owner.feature,
        geometry: {
          type: 'MultiPolygon',
          coordinates: [...ownerParts, ...annexedParts],
        },
      };
      dissolved.push({
        country: countryId,
        originalCode: baseId,
        owner: admin1Name(owner.feature, baseId),
        feature: admin1Name(entry.feature, baseId),
        source: sourceIdentity(entry.feature),
        rule: 'dissolve_small_annexed_island',
      });
    }
  }
  return { entries: retained, dissolved, ambiguousCodes };
}

function countryRegion(feature, id) {
  if (COUNTRY_REGION_OVERRIDES[id]) return COUNTRY_REGION_OVERRIDES[id];
  const p = feature.properties ?? {};
  const continent = String(p.CONTINENT ?? '').toLowerCase();
  const subregion = String(p.SUBREGION ?? '').toLowerCase();
  if (continent === 'south america') return 'south_america';
  if (continent === 'central america' || subregion === 'central america') return 'central_america';
  if (subregion === 'caribbean') return 'caribbean';
  if (continent === 'north america') return 'north_america';
  if (continent === 'europe') return 'europe';
  if (continent === 'asia') return 'asia';
  if (continent === 'africa') return 'africa';
  if (continent === 'oceania') return 'oceania';
  return null;
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

function crossesAntimeridian(collection) {
  let min = Infinity; let max = -Infinity;
  for (const [longitude] of collection.features
    .flatMap((feature) => pointsFromGeometry(feature.geometry))) {
    min = Math.min(min, longitude);
    max = Math.max(max, longitude);
  }
  if (!Number.isFinite(min)) return false;
  return min < -150 && max > 150 && max - min > 180;
}

function projectCommand(proj, input, output, dissolveById = false, clipBbox = null) {
  const clip = clipBbox ? ` -clip bbox=${clipBbox.join(',')}` : '';
  return `-i ${quote(input)}${dissolveById ? ' -dissolve2 field=id' : ''}${clip} -proj ${proj} -o format=geojson ${quote(output)}`;
}

// Layers that share the world frame keep the detail level of the old
// country-only maps: the tolerance and quantization step scale with the
// country's footprint in world units, so a small country still gets fine
// geometry while a large one stays within the vertex budget.
const SHARED_FRAME_REFERENCE_EXTENT = { width: 900 - 24, height: 700 - 24 };

// Bounding box of the collection in frame units. Features cut at the
// antimeridian (Fiji, New Zealand's Chatham Islands, the Aleutians) would
// otherwise span the whole frame width; only the side holding most of the
// vertices is measured in that case, which is where the camera will zoom.
function frameExtent(geo, frameWidth) {
  const parts = geo.features.flatMap((feature) => featureParts(feature));
  const measure = (selected) => {
    let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
    for (const part of selected) for (const ring of part) for (const [x, y] of ring) {
      minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
    }
    return { minX, minY, maxX, maxY };
  };
  const whole = measure(parts);
  if (whole.maxX - whole.minX <= frameWidth * 0.5) return whole;
  const sides = { left: [], right: [] };
  const weight = { left: 0, right: 0 };
  for (const part of parts) {
    const b = partBounds(part);
    const side = (b.minX + b.maxX) / 2 < frameWidth / 2 ? 'left' : 'right';
    sides[side].push(part);
    weight[side] += part.reduce((sum, ring) => sum + ring.length, 0);
  }
  const chosen = weight.left >= weight.right ? sides.left : sides.right;
  const extent = measure(chosen);
  // A genuinely wide country (Russia) keeps its full extent.
  return extent.maxX - extent.minX > frameWidth * 0.5 ? whole : extent;
}

function relativeDetail(geo, mapConfig) {
  const extent = frameExtent(geo, mapConfig.width);
  const ratio = Math.max(
    (extent.maxX - extent.minX) / SHARED_FRAME_REFERENCE_EXTENT.width,
    (extent.maxY - extent.minY) / SHARED_FRAME_REFERENCE_EXTENT.height,
    1e-4,
  );
  const base = mapConfig.relativeDetail;
  return {
    simplifyTolerance: Math.min(base.simplifyTolerance, base.simplifyTolerance * ratio),
    quantizationScale: Math.min(base.quantizationScale, base.quantizationScale * ratio),
    extent,
  };
}

async function projectAndNormalize(collection, mapConfig) {
  const raw = path.join(cacheDir, `${mapConfig.id}-input.json`);
  const projected = path.join(cacheDir, `${mapConfig.id}-projected.json`);
  const normalized = path.join(cacheDir, `${mapConfig.id}-normalized.json`);
  const simplified = path.join(cacheDir, `${mapConfig.id}-simplified.json`);
  const isCountryFocus = mapConfig.id.startsWith('country_focus_');
  const sharesFrame = mapConfig.sharedFrame != null;
  const projection = isCountryFocus && !sharesFrame && crossesAntimeridian(collection)
    ? `${mapConfig.proj} +lon_0=180`
    : mapConfig.proj;
  fs.writeFileSync(raw, JSON.stringify(collection));
  await runMapshaper(projectCommand(projection, raw, projected, mapConfig.dissolveById, mapConfig.clipBbox));
  const geo = JSON.parse(fs.readFileSync(projected, 'utf8'));
  const inputNames = new Map(JSON.parse(fs.readFileSync(raw, 'utf8')).features.map((feature) => [feature.properties?.id, feature.properties?.name]));
  for (const feature of geo.features) {
    feature.properties ??= {};
    feature.properties.name ??= inputNames.get(feature.properties.id) ?? feature.properties.id;
  }
  const all = geo.features.flatMap((feature) => pointsFromGeometry(feature.geometry));
  let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
  for (const [x, y] of all) { minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y); }
  const computedBounds = { minX, minY, maxX, maxY };
  // Layers with `sharedFrame` reuse the bounds captured by the frame owner so
  // they can be drawn on top of it. Other country focus maps are normalized
  // independently and never inherit or update the projection-wide bounds.
  const sharedBounds = sharesFrame ? normalizationBoundsByProjection.get(`frame:${mapConfig.sharedFrame}`) : null;
  if (sharesFrame && !sharedBounds) {
    throw new Error(`${mapConfig.id}: frame ${mapConfig.sharedFrame} must be built before this layer`);
  }
  const bounds = sharedBounds
    ?? (isCountryFocus
      ? computedBounds
      : mapConfig.normalizationBounds ?? normalizationBoundsByProjection.get(mapConfig.proj) ?? computedBounds);
  if (!isCountryFocus && mapConfig.captureNormalizationBounds) {
    normalizationBoundsByProjection.set(mapConfig.proj, computedBounds);
    mapConfig.normalizationBounds = computedBounds;
  }
  if (mapConfig.frameId) {
    normalizationBoundsByProjection.set(`frame:${mapConfig.frameId}`, computedBounds);
  }
  ({ minX, minY, maxX, maxY } = bounds);
  const padding = 12;
  const sx = (mapConfig.width - padding * 2) / (maxX - minX);
  const sy = (mapConfig.height - padding * 2) / (maxY - minY);
  const factor = Math.min(sx, sy);
  const offsetX = (mapConfig.width - (maxX - minX) * factor) / 2;
  const offsetY = (mapConfig.height - (maxY - minY) * factor) / 2;
  if (mapConfig.proj === '+proj=merc') {
    // Latitudes at the top and bottom edges of the viewBox, so the runtime can
    // undo Mercator's area inflation (spherical approximation is enough).
    const toLatitude = (y) => (2 * Math.atan(Math.exp(y / 6378137)) - Math.PI / 2) * 180 / Math.PI;
    mapConfig.mercatorLatitudes = {
      north: Number(toLatitude(maxY + offsetY / factor).toFixed(4)),
      south: Number(toLatitude(minY - (mapConfig.height - offsetY - (maxY - minY) * factor) / factor).toFixed(4)),
    };
  }
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
  if (mapConfig.relativeDetail) {
    const detail = relativeDetail(geo, mapConfig);
    mapConfig.simplifyTolerance = detail.simplifyTolerance;
    mapConfig.quantizationScale = detail.quantizationScale;
    mapConfig.frameExtent = detail.extent;
  }
  const quantizationScale = mapConfig.quantizationScale ?? 0.25;
  await runMapshaper(
    `-i ${quote(normalized)} -simplify interval=${mapConfig.simplifyTolerance} keep-shapes -o format=geojson ${quote(simplified)}`,
  );
  const result = JSON.parse(fs.readFileSync(simplified, 'utf8'));
  const originalById = new Map(geo.features.map((feature) => [feature.properties?.id, feature]));
  for (const feature of result.features) {
    if (polygonRings(feature, quantizationScale).length === 0) {
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
  // Tiny regions (a few quantum steps wide) can round the polylabel point onto
  // an edge. Try the centre of the largest ring, then its vertices offset by
  // half a step towards the inside, before giving up on the first vertex.
  const xs = largest.map((p) => p[0] / scale); const ys = largest.map((p) => p[1] / scale);
  const center = [Math.round((Math.min(...xs) + Math.max(...xs)) / 2), Math.round((Math.min(...ys) + Math.max(...ys)) / 2)];
  if (inside(center, rings)) return center;
  for (const ring of rings) for (let i = 0; i < ring.length; i += 2) {
    for (const [dx, dy] of [[1, 1], [-1, 1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const point = [ring[i] + dx, ring[i + 1] + dy];
      if (inside(point, rings)) return point;
    }
  }
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
  const scale = config.quantizationScale ?? 0.25;
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
    // Rings that quantize to a zero-area zigzag (atolls, islets) have no fill
    // and no interior for the marker anchor. Give each a 2x2 footprint.
    for (let r = 0; r < rings.length; r++) {
      const ring = rings[r];
      let twiceArea = 0;
      for (let i = 0, j = ring.length - 2; i < ring.length; j = i, i += 2) twiceArea += ring[j] * ring[i + 1] - ring[i] * ring[j + 1];
      if (Math.abs(twiceArea) >= 2) continue;
      let x = Infinity; let y = Infinity;
      for (let i = 0; i < ring.length; i += 2) { x = Math.min(x, ring[i]); y = Math.min(y, ring[i + 1]); }
      rings[r] = [x, y, x + 2, y, x + 2, y + 2, x, y + 2];
    }
    let coords = rings.flatMap((ring) => ring.reduce((all, value, i) => { if (i % 2 === 0) all.push([value, ring[i + 1]]); return all; }, []));
    let bbox = [Math.min(...coords.map((p) => p[0])), Math.min(...coords.map((p) => p[1])), Math.max(...coords.map((p) => p[0])), Math.max(...coords.map((p) => p[1]))];
    if (bbox[2] - bbox[0] === 0 || bbox[3] - bbox[1] === 0) {
      // Quantization collapsed the region to a sliver; keep a visible,
      // hittable 2x2 footprint instead (same rule as sub-quantum regions).
      const x = bbox[0]; const y = bbox[1];
      rings.length = 0;
      rings.push([x, y, x + 2, y, x + 2, y + 2, x, y + 2]);
      coords = [[x, y], [x + 2, y + 2]];
      bbox = [x, y, x + 2, y + 2];
    }
    return { id, name, rings, bbox, anchor: anchorFor(rings, scale) };
  });
  const ids = new Set();
  for (const region of regions) {
    if (!/^[A-Z]{2}$/.test(region.id) && !/^[A-Z]{2}-[A-Z0-9]{1,3}$/.test(region.id) && !/^BR-\d{7}$/.test(region.id)) throw new Error(`${config.id}: invalid id ${region.id}`);
    if (ids.has(region.id)) throw new Error(`${config.id}: duplicate id ${region.id}`);
    ids.add(region.id);
    if (region.rings.isEmpty) throw new Error(`${config.id}: empty geometry for ${region.id}`);
    for (const ring of region.rings) {
      if (ring.length < 6) throw new Error(`${config.id}: invalid ring for ${region.id}`);
      for (let i = 0; i < ring.length; i += 2) {
        const next = (i + 2) % ring.length;
        if (!config.allowLongSegments && Math.abs(ring[next] - ring[i]) * scale > config.width / 2 || !config.allowLongSegments && Math.abs(ring[next + 1] - ring[i + 1]) * scale > config.width / 2) {
          throw new Error(`${config.id}: antimeridian-like segment in ${region.id}`);
        }
      }
    }
  }
  const lines = sharedLines(regions);
  const mercatorLatitudes = config.mercatorLatitudes ?? null;
  return { id: config.id, width: config.width, height: config.height, scale, focusRegionPrefix: config.focusRegionPrefix, mercatorLatitudes, regions, inner: lines.inner, outline: lines.outline, nearlyShared: lines.nearlyShared, edgeCounts: lines.edgeCounts };
}

function boundsForRegions(regions, scale, predicate = () => true) {
  let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
  for (const region of regions) {
    if (!predicate(region)) continue;
    minX = Math.min(minX, region.bbox[0] * scale);
    minY = Math.min(minY, region.bbox[1] * scale);
    maxX = Math.max(maxX, region.bbox[2] * scale);
    maxY = Math.max(maxY, region.bbox[3] * scale);
  }
  return { minX, minY, maxX, maxY };
}

function validateBoundsWithinViewBox(map, config) {
  const tolerance = 1;
  const viewBox = { minX: 0, minY: 0, maxX: config.width, maxY: config.height };
  const check = (bounds, label, requireFill = true) => {
    if (!Number.isFinite(bounds.minX)) throw new Error(`${config.id}: ${label} is empty`);
    if (bounds.minX < viewBox.minX - tolerance || bounds.minY < viewBox.minY - tolerance ||
        bounds.maxX > viewBox.maxX + tolerance || bounds.maxY > viewBox.maxY + tolerance) {
      throw new Error(`${config.id}: ${label} leaves viewBox ${JSON.stringify(bounds)}`);
    }
    const width = bounds.maxX - bounds.minX;
    const height = bounds.maxY - bounds.minY;
    if (requireFill && width < config.width * 0.75 && height < config.height * 0.75) {
      throw new Error(`${config.id}: ${label} does not fill the viewBox reasonably: ${JSON.stringify(bounds)}`);
    }
  };
  check(boundsForRegions(map.regions, map.scale), 'contentBounds', !config.id.includes('focus'));
  if (config.focusRegionPrefix) {
    check(
      boundsForRegions(map.regions, map.scale, (region) =>
        region.id.startsWith(config.focusRegionPrefix),
      ),
      'focusBounds',
      !config.id.includes('focus'),
    );
  }
}

function writeAsset(map, filename, directory = exampleAssetsDir) {
  const bytes = encode(map);
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, filename), bytes);
  return { bytes: bytes.length, vertices: map.regions.reduce((sum, region) => sum + region.rings.reduce((n, ring) => n + ring.length / 2, 0), 0), maxRegionVertices: Math.max(...map.regions.map((r) => r.rings.reduce((n, ring) => n + ring.length / 2, 0))) };
}

function byteSize(directory, predicate = () => true) {
  if (!fs.existsSync(directory)) return 0;
  return fs.readdirSync(directory, { withFileTypes: true }).reduce((sum, entry) => {
    const target = path.join(directory, entry.name);
    return sum + (entry.isFile() && predicate(entry.name) ? fs.statSync(target).size : 0);
  }, 0);
}

function trackedGeneratedBytesBefore() {
  try {
    const output = execFileSync('git', ['ls-tree', '-rl', 'HEAD', '--', 'lib/src/data/generated'], { encoding: 'utf8' });
    return output.split('\n').filter(Boolean).reduce((sum, line) => sum + Number(line.trim().split(/\s+/)[3]), 0);
  } catch (_) {
    return null;
  }
}

function writeGenerated(map) {
  const bytes = encode(map); const base64 = bytes.toString('base64');
  const symbol = map.id.replace(/(^|_)(.)/g, (_, __, c) => c.toUpperCase());
  const target = path.join(generatedDir, `${map.id}.g.dart`);
  const publicId = map.id.replaceAll('_', '');
  const latitudes = map.mercatorLatitudes ? `\n  mercatorLatitudes: (north: ${map.mercatorLatitudes.north}, south: ${map.mercatorLatitudes.south}),` : '';
  const latitudesInline = map.mercatorLatitudes ? ` mercatorLatitudes: (north: ${map.mercatorLatitudes.north}, south: ${map.mercatorLatitudes.south}),` : '';
  fs.writeFileSync(target, `// GENERATED CODE - DO NOT MODIFY BY HAND.\nimport 'dart:convert';\nimport '../codec.dart';\nimport '../models.dart';\n\nconst String _data = '${base64}';\nMapDefinition? _cache${symbol};\n\n/// Lazily decodes the embedded ${publicId} map.\nMapDefinition get generated${symbol} => _cache${symbol} ??= decodeGenerated(\n  base64Decode(_data),\n  id: '${publicId}',${map.focusRegionPrefix ? `\n  focusRegionPrefix: '${map.focusRegionPrefix}',` : ''}${latitudes}\n);\n\n/// Decodes and caches the embedded ${publicId} map off the UI isolate.\nFuture<MapDefinition> preloadGenerated${symbol}() async {\n  final cached = _cache${symbol};\n  if (cached != null) return cached;\n  final decoded = await decodeGeneratedAsync(_data, id: '${publicId}',${map.focusRegionPrefix ? ` focusRegionPrefix: '${map.focusRegionPrefix}',` : ''}${latitudesInline});\n  return _cache${symbol} ??= decoded;\n}\n`);
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
  // The world uses Mercator so every country keeps its familiar (conformal)
  // shape when the camera zooms in, which is what makes a continuous
  // world -> country zoom look right. Latitudes are clipped to [-60, 84]:
  // Antarctica is excluded and the clip keeps Greenland's size tolerable.
  const worldConfig = {
    id: 'world',
    frameId: 'world',
    width: 1200,
    height: 790,
    proj: '+proj=merc',
    clipBbox: [-180, -60, 180, 84],
    simplifyTolerance: 0.6,
    features: countries.filter((item) => item.id !== 'AQ').map((item) => featureFor(item.id === 'FR' ? france : item.feature, item.id, item.name)),
  };
  const configs = [
    worldConfig,
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
  const worldCountries = countries.filter((item) => item.id !== 'AQ');
  const worldCountryIds = new Set(worldCountries.map((item) => item.id));
  const admin1FeaturesByCountry = new Map();
  const admin1RawFeaturesByCountry = new Map();
  const ambiguousAdmin1Codes = new Set();
  const duplicateAdmin1Resolutions = [];
  const dissolvedAdmin1Features = [];
  const rejectedAdmin1ByCountry = new Map();
  const nonMatchingCodes = new Set();
  for (const feature of admin1.features) {
    const sourceCodes = admin1SourceCodes(feature);
    for (const code of sourceCodes) {
      const normalized = code.toUpperCase().replaceAll('.', '-');
      if (!/^[A-Z]{2}-[A-Z0-9]{1,3}$/.test(normalized)) nonMatchingCodes.add(code);
    }
    const countryId = admin1CountryId(feature);
    if (!countryId || !worldCountryIds.has(countryId) || countryId === 'BR') continue;
    const id = admin1Id(feature, countryId);
    if (!id) {
      const reasons = rejectedAdmin1ByCountry.get(countryId) ?? new Set();
      reasons.add('feature_without_canonical_id');
      rejectedAdmin1ByCountry.set(countryId, reasons);
      continue;
    }
    if (!id.startsWith(`${countryId}-`)) {
      throw new Error(`admin-1 ${id}: canonical prefix does not match country ${countryId}`);
    }
    const rawList = admin1RawFeaturesByCountry.get(countryId) ?? [];
    rawList.push({ feature, id });
    admin1RawFeaturesByCountry.set(countryId, rawList);
  }
  for (const [countryId, rawListBeforeDissolve] of admin1RawFeaturesByCountry) {
    const dissolution = dissolveAnnexedSmallIslands(rawListBeforeDissolve, countryId);
    dissolvedAdmin1Features.push(...dissolution.dissolved);
    for (const code of dissolution.ambiguousCodes) ambiguousAdmin1Codes.add(code);
    const rawList = dissolution.entries;
    admin1RawFeaturesByCountry.set(countryId, rawList);
    const resolution = resolveAdmin1Ids(rawList, countryId);
    for (const code of resolution.ambiguousCodes) ambiguousAdmin1Codes.add(code);
    duplicateAdmin1Resolutions.push(...resolution.resolutions);
    for (const item of dissolution.dissolved) {
      if (resolution.resolutions.some((resolved) => resolved.originalCode === item.originalCode)) continue;
      const originalGroup = rawListBeforeDissolve.filter((entry) => entry.id === item.originalCode);
      const owner = chooseAdmin1Owner(originalGroup, item.originalCode);
      duplicateAdmin1Resolutions.push({
        country: countryId,
        originalCode: item.originalCode,
        owner: { source: sourceIdentity(owner.feature), name: admin1Name(owner.feature, item.originalCode), code: item.originalCode },
        secondary: [{ source: item.source, name: item.feature, code: null, target: item.originalCode, rule: item.rule }],
      });
    }
    const features = rawList.map(({ feature, id }) => featureFor(feature, id, admin1Name(feature, id)));
    admin1FeaturesByCountry.set(countryId, features);
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
  const southAmericaFocusCountries = ['AR', 'BO', 'BR', 'CL', 'CO', 'EC', 'GY', 'PE', 'PY', 'SR', 'UY', 'VE'];
  for (const countryId of southAmericaFocusCountries) {
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
  const rawBrazilById = new Map();
  for (const feature of admin1.features) {
    if (admin1CountryId(feature) !== 'BR') continue;
    const id = admin1Id(feature, 'BR');
    if (id) rawBrazilById.set(id, { feature, id });
  }
  const focusFeaturesByCountry = new Map([['BR', stateFeatures]]);
  for (const [countryId, features] of admin1FeaturesByCountry) {
    focusFeaturesByCountry.set(countryId, features);
  }
  const focusCountries = [...focusFeaturesByCountry.keys()].sort();
  const countriesWithoutReliableAdmin1 = worldCountries
    .filter((country) => !focusFeaturesByCountry.has(country.id))
    .map((country) => ({
      iso2: country.id,
      reason: rejectedAdmin1ByCountry.has(country.id)
        ? [...rejectedAdmin1ByCountry.get(country.id)]
        : ['no_admin1_features'],
    }));
  for (const countryId of focusCountries) {
    const selected = focusFeaturesByCountry.get(countryId);
    if (!selected || selected.length === 0) {
      throw new Error(`Missing reliable admin-1 regions for ${countryId}`);
    }
    configs.push({
      id: `country_focus_${countryId.toLowerCase()}`,
      // Drawn on top of the world map: same projection, clip, normalization
      // bounds and viewBox, so coordinates line up without re-projection.
      sharedFrame: 'world',
      width: worldConfig.width,
      height: worldConfig.height,
      proj: worldConfig.proj,
      clipBbox: worldConfig.clipBbox,
      relativeDetail: { simplifyTolerance: 0.6, quantizationScale: 0.25 },
      focusRegionPrefix: `${countryId}-`,
      packageAsset: `${countryId}.smap`,
      features: selected,
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
  const ambiguousGeoNamesAliases = new Set();
  const geoNamesAliasOwners = new Map();
  for (const [countryId, items] of admin1RawFeaturesByCountry) {
    for (const { feature, id } of items) {
      const rawCode = String(feature.properties?.gn_a1_code ?? '').trim().toUpperCase();
      if (!rawCode.includes('.')) continue;
      const alias = `${countryId}-${rawCode.split('.').pop()}`;
      const owner = geoNamesAliasOwners.get(alias);
      if (owner && owner !== id) ambiguousGeoNamesAliases.add(alias);
      geoNamesAliasOwners.set(alias, id);
    }
  }
  for (const [id, item] of rawBrazilById) {
    const rawCode = String(item.feature.properties?.gn_a1_code ?? '').trim().toUpperCase();
    if (!rawCode.includes('.')) continue;
    const alias = `BR-${rawCode.split('.').pop()}`;
    const owner = geoNamesAliasOwners.get(alias);
    if (owner && owner !== id) ambiguousGeoNamesAliases.add(alias);
    geoNamesAliasOwners.set(alias, id);
  }
  const canonicalFocusIds = new Set();
  for (const features of focusFeaturesByCountry.values()) {
    for (const feature of features) canonicalFocusIds.add(feature.properties.id);
  }
  const catalogSubdivisions = [];
  const catalogCodeOwners = new Map();
  const aliasOwners = new Map();
  for (const countryId of focusCountries) {
    const selected = countryId === 'BR'
      ? stateFeatures.map((feature) => ({
          feature: rawBrazilById.get(feature.properties.id)?.feature ?? null,
          id: feature.properties.id,
          mapFeature: feature,
        }))
      : (admin1RawFeaturesByCountry.get(countryId) ?? []).map((item) => ({ ...item, mapFeature: null }));
    for (const item of selected) {
      const raw = item.feature;
      const p = raw?.properties ?? {};
      const mapId = item.id;
      if (!mapId || !mapId.startsWith(`${countryId}-`)) {
        throw new Error(`Catalog region ${mapId} has a prefix different from ${countryId}`);
      }
      const names = raw ? {
        name_en: p.name_en || p.NAME_EN || p.name || p.NAME || mapId,
        name_pt: p.name_pt || p.NAME_PT || p.name_en || p.NAME_EN || p.name || p.NAME || mapId,
        name_es: p.name_es || p.NAME_ES || p.name_en || p.NAME_EN || p.name || p.NAME || mapId,
      } : {
        name_en: item.mapFeature.properties.name,
        name_pt: item.mapFeature.properties.name,
        name_es: item.mapFeature.properties.name,
      };
      const sourceCodes = raw ? admin1SourceCodes(raw) : ['IBGE', mapId];
      const aliases = raw
        ? admin1Aliases(raw, countryId, mapId, ambiguousAdmin1Codes).filter((alias) => !ambiguousGeoNamesAliases.has(alias) && (!canonicalFocusIds.has(alias) || alias === mapId))
        : [mapId];
      const existingCodeOwner = catalogCodeOwners.get(mapId);
      if (existingCodeOwner && existingCodeOwner !== countryId) {
        throw new Error(`Catalog code ${mapId} points to both ${existingCodeOwner} and ${countryId}`);
      }
      if (catalogCodeOwners.has(mapId)) {
        throw new Error(`Duplicate catalog code ${mapId}`);
      }
      catalogCodeOwners.set(mapId, countryId);
      for (const alias of aliases) {
        const owner = aliasOwners.get(alias);
        if (owner && owner !== mapId) {
          throw new Error(`Alias ${alias} points to both ${owner} and ${mapId}`);
        }
        aliasOwners.set(alias, mapId);
      }
      catalogSubdivisions.push({
        code: mapId,
        country_iso: countryId,
        ...names,
        type: raw?.properties?.type_en || raw?.properties?.TYPE_EN || raw?.properties?.type || 'State',
        source_codes: [...new Set(sourceCodes)],
        aliases,
      });
    }
  }
  const catalogCountries = worldCountries.map((country) => {
    const names = countryNameFields(country.feature, country.id);
    const iso3 = countryIso3(country.feature, country.id);
    const region = countryRegion(country.feature, country.id);
    if (!/^[A-Z]{3}$/.test(iso3)) {
      throw new Error(`Invalid country ISO3 ${country.id}: ${iso3}`);
    }
    if (!ALLOWED_REGIONS.has(region)) {
      throw new Error(`Country ${country.id} has unsupported region ${region}`);
    }
    return {
      iso2: country.id,
      iso3,
      ...names,
      region,
      has_focus: focusCountries.includes(country.id),
    };
  });
  // French Guiana is drawn as part of France on the world map but is its own
  // entry in regional maps and in geographic data, so apps can list it.
  catalogCountries.push({
    iso2: 'GF',
    iso3: 'GUF',
    name_en: 'French Guiana',
    name_pt: overrides.GF,
    name_es: 'Guayana Francesa',
    region: 'south_america',
    has_focus: false,
  });
  if (new Set(catalogCountries.map((country) => country.iso3)).size !== catalogCountries.length) {
    throw new Error('Country ISO3 codes must be unique');
  }
  const catalog = {
    version: 1,
    generated_from: 'Natural Earth admin-0 50m + Natural Earth admin-1 10m + IBGE UFs',
    countries: catalogCountries,
    subdivisions: catalogSubdivisions,
  };
  const report = {
    format: 'SMAP v2',
    world: {
      countries: worldCountries.length,
      focusCountries,
      countriesWithoutReliableAdmin1,
      subdivisionsByCountry: Object.fromEntries(worldCountries.map((country) => [country.id, catalogSubdivisions.filter((item) => item.country_iso === country.id).length])),
    },
    consistency: {
      nonMatchingCodes: [...nonMatchingCodes].sort(),
      nonMatchingSourceCodes: [...nonMatchingCodes].sort(),
      nonMatchingCanonicalCodes: [],
      ambiguousSourceAliases: [...ambiguousGeoNamesAliases].sort(),
      resolvedDuplicateCodes: [...ambiguousAdmin1Codes].sort(),
      resolvedDuplicateCodeCount: ambiguousAdmin1Codes.size,
      duplicateCodeResolutions: duplicateAdmin1Resolutions,
      dissolvedAnnexedFeatures: dissolvedAdmin1Features,
      stableHashFallbackCount: duplicateAdmin1Resolutions.reduce((count, resolution) => count + resolution.secondary.filter((item) => item.rule === 'stable_hash_fallback').length, 0),
      primaryIsoCodeReplacements: duplicateAdmin1Resolutions.filter((resolution) => resolution.owner.code !== resolution.originalCode),
      maxCanonicalCodeLength: Math.max(0, ...catalogSubdivisions.map((item) => item.code.length)),
      totalSubdivisions: catalogSubdivisions.length,
    },
    maps: {},
  };
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
    const expected = { world: 234, latin_america: 34, south_america: 13, brazil_states: 27, brazil_municipalities: 5570, ...focusExpectedRegions }[config.id];
    if (expected != null && model.regions.length !== expected) throw new Error(`${config.id}: expected ${expected} regions, got ${model.regions.length}`);
    if (config.focusRegionPrefix) {
      const focused = model.regions.filter((region) => region.id.startsWith(config.focusRegionPrefix));
      if (focused.length === 0) throw new Error(`${config.id}: no region matches focus prefix ${config.focusRegionPrefix}`);
      if (focused.some((region) => !region.id.startsWith(config.focusRegionPrefix))) throw new Error(`${config.id}: focus prefix mismatch`);
    }
    validateBoundsWithinViewBox(model, config);
    if (config.id === 'brazil_municipalities') {
      const prefixes = new Set(model.regions.map((region) => region.id.slice(3, 5)));
      const expectedUfPrefixes = new Set(['11','12','13','14','15','16','17','21','22','23','24','25','26','27','28','29','31','32','33','35','41','42','43','50','51','52','53']);
      for (const prefix of expectedUfPrefixes) if (!prefixes.has(prefix)) throw new Error(`Missing municipalities for UF code ${prefix}`);
    }
    const limit = { world: 40000, latin_america: 20000, south_america: 12000, brazil_states: 12000, brazil_municipalities: 300000, ...Object.fromEntries(Object.keys(focusExpectedRegions).map((id) => [id, 30000])) }[config.id] ?? (config.packageAsset ? 150000 : 30000);
    const stats = config.asset
      ? writeAsset(model, config.asset)
      : config.packageAsset
        ? writeAsset(model, config.packageAsset, packageAssetsDir)
        : writeGenerated(model);
    if (stats.vertices > limit) throw new Error(`${config.id}: ${stats.vertices} vertices exceed ${limit}`);
    report.maps[config.id] = {
      regions: model.regions.length,
      vertices: stats.vertices,
      bytes: stats.bytes,
      maxRegionVertices: stats.maxRegionVertices,
      viewBox: [config.width, config.height],
      ...(model.mercatorLatitudes ? { mercatorLatitudes: model.mercatorLatitudes } : {}),
      quantizationScale: model.scale,
      simplificationTolerance: config.simplifyTolerance,
      estimatedMaxError: config.simplifyTolerance,
      innerBorders: model.inner.length,
      outlinePolylines: model.outline.length,
      innerEdges: model.edgeCounts.inner,
      outlineEdges: model.edgeCounts.outline,
      nearlySharedEdges: model.nearlyShared,
      ...(config.asset ? { asset: `example/assets/maps/${config.asset}`, assetBytes: stats.bytes } : {}),
      ...(config.packageAsset ? { asset: `assets/maps/country_focus/${config.packageAsset}`, assetBytes: stats.bytes } : {}),
    };
  }
  const countryFocusMaps = focusCountries.map((countryId) => report.maps[`country_focus_${countryId.toLowerCase()}`]);
  report.measurements = {
    newCountryFocusAssetsBytes: countryFocusMaps.reduce((sum, map) => sum + map.bytes, 0),
    largestCountryFocus: countryFocusMaps.reduce((largest, map, index) => map.bytes > largest.bytes ? { ...map, iso2: focusCountries[index] } : largest, { bytes: 0, iso2: null }),
    averageCountryFocusAssetBytes: countryFocusMaps.length === 0 ? 0 : Math.round(countryFocusMaps.reduce((sum, map) => sum + map.bytes, 0) / countryFocusMaps.length),
    totalSubdivisions: catalogSubdivisions.length,
    packageRuntimeBytesBefore: trackedGeneratedBytesBefore(),
    packageRuntimeBytesAfter: byteSize(generatedDir, (name) => name.endsWith('.g.dart')) + byteSize(packageAssetsDir, (name) => name.endsWith('.smap')) + fs.statSync(path.join(catalogDir, 'geo_catalog.json')).size,
    embeddedGeneratedBytesAfter: byteSize(generatedDir, (name) => name.endsWith('.g.dart')),
    catalogBytes: fs.statSync(path.join(catalogDir, 'geo_catalog.json')).size,
  };
  fs.writeFileSync(path.join(catalogDir, 'geo_catalog.json'), `${JSON.stringify(catalog, null, 2)}\n`);
  // Compact runtime copy of the catalog (names only, no source codes or
  // aliases) shipped as a package asset for apps that need localized country
  // and subdivision names without bundling their own copy.
  const runtimeCatalog = {
    version: 1,
    countries: catalogCountries.map((country) => [
      country.iso2, country.iso3, country.name_en, country.name_pt, country.name_es, country.region, country.has_focus ? 1 : 0,
    ]),
    subdivisions: Object.fromEntries(
      focusCountries.map((countryId) => [
        countryId,
        catalogSubdivisions
          .filter((item) => item.country_iso === countryId)
          .map((item) => [item.code, item.name_en, item.name_pt, item.name_es, item.type]),
      ]),
    ),
  };
  fs.writeFileSync(path.join(packageCatalogDir, 'geo_names.json'), JSON.stringify(runtimeCatalog));
  report.measurements.runtimeCatalogBytes = fs.statSync(path.join(packageCatalogDir, 'geo_names.json')).size;
  fs.writeFileSync(path.join(generatedDir, 'country_focus_catalog.g.dart'), `// GENERATED CODE - DO NOT MODIFY BY HAND.\n\nconst Set<String> generatedCountryFocusCountries = <String>{\n${focusCountries.map((countryId) => "  '" + countryId + "',").join('\n')}\n};\n`);
  fs.writeFileSync(path.join(root, 'ATTRIBUTION.md'), `# Map data attribution\n\n- Natural Earth 50m admin-0 cultural (manifest date 2025-02-01): public domain, downloaded from https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip.\n- Natural Earth 10m admin-1 states and provinces (manifest date 2025-02-01): public domain, SHA-256 efc59726337323058f9446210adc96673179cd344e053666ee3d28cb58ba2b05, downloaded from https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_1_states_provinces.zip. These focus layers contain admin-1 regions only; country-only assets are distributed under assets/maps/country_focus/ and never contain cities or municipalities.\n- IBGE UFs (manifest date 2025-02-01): https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&intrarregiao=UF&qualidade=intermediaria, intermediate quality; names from https://servicodados.ibge.gov.br/api/v1/localidades/estados. The geometry was simplified with a 0.6 view-box-unit tolerance, topology-preserving keep-shapes, and quantized to a 0.25 view-box-unit grid.\n- IBGE municipalities (manifest date 2025-02-01): https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?formato=application/vnd.geo+json&intrarregiao=municipio&qualidade=intermediaria, intermediate quality; names from https://servicodados.ibge.gov.br/api/v1/localidades/municipios. Simplified and quantized like the UFs; distributed only as the optional example asset example/assets/maps/brazil_municipalities.smap, not inside lib/.\n- Source credit: \"Fonte: IBGE\" must accompany apps that display the Brazilian layers. Confirm the current IBGE terms of use before commercial distribution.\n- Build tools: mapshaper 0.7.98 (MIT), polylabel 2.1.0 (ISC). They are build-only dependencies; the Flutter package has no runtime dependency.\n\nCollision policy: for duplicate admin-1 source codes, the feature matching the known ISO name keeps the canonical code; otherwise the largest geometry is the deterministic tie-breaker. A secondary feature uses an alternate ISO code or short source suffix, then a stable base36 hash only when every source suffix is occupied. A secondary feature is dissolved into its owner only when it is named as an island or territory, is at most 5% of the owner geometry, and shares the owner's duplicate source code.\n\nKosovo is retained as XK when present. Somaliland, Northern Cyprus and other unrecognized disputed fragments are omitted in favor of their sovereign feature; Antarctica is excluded. French Guiana is merged into FR for the world map and retained as GF in regional maps.\n`);
  fs.writeFileSync(path.join(here, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
}

main().catch((error) => { console.error(error.stack || error); process.exitCode = 1; });
