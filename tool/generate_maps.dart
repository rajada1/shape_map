// GENERATED FILES ARE PRODUCED BY THIS SCRIPT. Do not edit them manually.
import 'dart:io';
import 'dart:math' as math;

import 'svg_path_parser.dart';

const _countryManifest = <String, List<String>>{
  'stroke0_2763_5777': ['VE', 'Venezuela'],
  'stroke2_2763_5777': ['UY', 'Uruguai'],
  'inline:191 36': ['SR', 'Suriname'],
  'stroke5_2763_5777': ['PE', 'Peru'],
  'stroke7_2763_5777': ['PY', 'Paraguai'],
  'stroke9_2763_5777': ['GY', 'Guiana'],
  'inline:188 51': ['GF', 'Guiana Francesa'],
  'stroke12_2763_5777': ['EC', 'Equador'],
  'stroke14_2763_5777': ['CO', 'Colômbia'],
  'stroke16_2763_5777': ['CL', 'Chile'],
  'stroke18_2763_5777': ['BR', 'Brasil'],
  'stroke20_2763_5777': ['BO', 'Bolívia'],
  'stroke22_2763_5777': ['AR', 'Argentina'],
};

const _countryAnchors = <String, List<double>>{
  'BR': [215, 125],
  'AR': [142, 268],
  'PE': [92, 112],
  'CL': [88, 240],
  'BO': [140, 150],
  'PY': [172, 186],
  'EC': [64, 72],
  'UY': [188, 236],
};

const _stateIds = <String, String>{
  'stroke0_2764_5792': 'AC',
  'stroke2_2764_5792': 'AL',
  'stroke4_2764_5792': 'AM',
  'stroke6_2764_5792': 'AP',
  'stroke8_2764_5792': 'BA',
  'stroke10_2764_5792': 'CE',
  'stroke12_2764_5792': 'ES',
  'stroke14_2764_5792': 'GO',
  'stroke16_2764_5792': 'MA',
  'stroke18_2764_5792': 'MG',
  'stroke20_2764_5792': 'MS',
  'stroke22_2764_5792': 'MT',
  'stroke24_2764_5792': 'PA',
  'stroke26_2764_5792': 'PB',
  'stroke28_2764_5792': 'PE',
  'stroke30_2764_5792': 'PI',
  'stroke32_2764_5792': 'PR',
  'stroke34_2764_5792': 'RJ',
  'stroke36_2764_5792': 'RN',
  'stroke38_2764_5792': 'RO',
  'stroke40_2764_5792': 'RR',
  'stroke42_2764_5792': 'RS',
  'stroke44_2764_5792': 'SC',
  'stroke46_2764_5792': 'SE',
  'stroke48_2764_5792': 'SP',
  'stroke50_2764_5792': 'TO',
};

const _stateNames = <String, String>{
  'AC': 'Acre',
  'AL': 'Alagoas',
  'AM': 'Amazonas',
  'AP': 'Amapá',
  'BA': 'Bahia',
  'CE': 'Ceará',
  'ES': 'Espírito Santo',
  'GO': 'Goiás',
  'MA': 'Maranhão',
  'MG': 'Minas Gerais',
  'MS': 'Mato Grosso do Sul',
  'MT': 'Mato Grosso',
  'PA': 'Pará',
  'PB': 'Paraíba',
  'PE': 'Pernambuco',
  'PI': 'Piauí',
  'PR': 'Paraná',
  'RJ': 'Rio de Janeiro',
  'RN': 'Rio Grande do Norte',
  'RO': 'Rondônia',
  'RR': 'Roraima',
  'RS': 'Rio Grande do Sul',
  'SC': 'Santa Catarina',
  'SE': 'Sergipe',
  'SP': 'São Paulo',
  'TO': 'Tocantins',
  'DF': 'Distrito Federal',
};

void main() {
  final root = Directory.current.path;
  final first = _readSvg('$root/mapa_view_1.svg');
  final second = _readSvg('$root/mapa_view_2.svg');
  _writeMap(
    '$root/lib/src/data/generated/south_america_countries.g.dart',
    mapId: 'southAmericaCountries',
    viewBox: const [342, 400],
    entries: _countryEntries(first),
  );
  _writeMap(
    '$root/lib/src/data/generated/brazil_states.g.dart',
    mapId: 'brazilStates',
    viewBox: const [342, 330],
    entries: _stateEntries(second),
  );
  stdout.writeln(
    'Generated south_america_countries.g.dart and brazil_states.g.dart',
  );
}

Map<String, String> _readSvg(String path) {
  final content = File(path).readAsStringSync();
  final paths = <String, String>{};
  final tagPattern = RegExp(r'<path\b[^>]*>', multiLine: true);
  for (final match in tagPattern.allMatches(content)) {
    final tag = match.group(0)!;
    final attrs = _attributes(tag);
    final d = attrs['d'];
    if (d == null) continue;
    final id = attrs['id'];
    if (id != null && id.startsWith('stroke')) {
      paths[id] = d;
    } else if (attrs['stroke'] == null &&
        (attrs['fill'] == '#E2E9ED' || attrs['fill'] == '#FFDBC9')) {
      paths['inline:${d.substring(1, math.min(d.length, 10))}'] = d;
    }
  }
  for (final match in RegExp(
    r'<rect\b[^>]*>',
    multiLine: true,
  ).allMatches(content)) {
    final attrs = _attributes(match.group(0)!);
    if (attrs['fill'] != '#C04F00') continue;
    final x = double.tryParse(attrs['x'] ?? '');
    final y = double.tryParse(attrs['y'] ?? '');
    final width = double.tryParse(attrs['width'] ?? '');
    if (x != null && y != null && width != null) {
      final index = paths.keys.where((key) => key.startsWith('marker:')).length;
      paths['marker:$index'] = '${x + width / 2},${y + width / 2}';
    }
  }
  return paths;
}

Map<String, String> _attributes(String tag) {
  final result = <String, String>{};
  final pattern = RegExp(r'([\w:-]+)="([^"]*)"');
  for (final match in pattern.allMatches(tag)) {
    result[match.group(1)!] = match.group(2)!;
  }
  return result;
}

List<_Entry> _countryEntries(Map<String, String> paths) {
  final entries = <_Entry>[];
  for (final item in _countryManifest.entries) {
    final d = paths[item.key] ?? _findInline(paths, item.key);
    if (d == null) throw StateError('Missing country path ${item.key}');
    final commands = SvgPathParser.parse(d);
    final id = item.value[0];
    final requestedAnchor = _countryAnchors[id];
    final anchor =
        requestedAnchor != null && _contains(commands, requestedAnchor)
        ? requestedAnchor
        : _fallbackAnchor(commands);
    entries.add(_Entry(id, item.value[1], commands, anchor));
  }
  return entries;
}

String? _findInline(Map<String, String> paths, String key) {
  final prefix = key.substring('inline:'.length);
  return paths.entries
      .where(
        (entry) =>
            entry.key.startsWith('inline:') &&
            entry.value.startsWith('M$prefix'),
      )
      .map((entry) => entry.value)
      .firstOrNull;
}

List<_Entry> _stateEntries(Map<String, String> paths) {
  final entries = <_Entry>[];
  final anchors = <String, List<double>>{};
  final stateCommands = <String, List<ParsedCommand>>{};
  for (final item in _stateIds.entries) {
    final d = paths[item.key];
    if (d == null) throw StateError('Missing state path ${item.key}');
    stateCommands[item.value] = SvgPathParser.parse(d);
  }
  final dfEntry = paths.entries.firstWhere(
    (entry) => entry.value.startsWith('M218 173'),
  );
  final dfCommands = SvgPathParser.parse(dfEntry.value);
  for (final item in paths.entries.where(
    (entry) => entry.key.startsWith('marker:'),
  )) {
    final values = item.value.split(',').map(double.parse).toList();
    final point = <double>[values[0], values[1]];
    if (_contains(dfCommands, point)) {
      anchors['DF'] ??= point;
      continue;
    }
    for (final state in stateCommands.entries) {
      if (_contains(state.value, point)) {
        anchors[state.key] ??= point;
        break;
      }
    }
  }
  anchors['DF'] ??= [214, 170.5];
  for (final item in _stateIds.entries) {
    final commands = stateCommands[item.value]!;
    final id = 'BR-${item.value}';
    final anchor = anchors[item.value] ?? _fallbackAnchor(commands);
    entries.add(_Entry(id, _stateNames[item.value]!, commands, anchor));
  }
  entries.add(_Entry('BR-DF', _stateNames['DF']!, dfCommands, anchors['DF']!));
  return entries;
}

List<double> _fallbackAnchor(List<ParsedCommand> commands) {
  final points = _points(commands);
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final point in points) {
    minX = math.min(minX, point[0]);
    minY = math.min(minY, point[1]);
    maxX = math.max(maxX, point[0]);
    maxY = math.max(maxY, point[1]);
  }
  final center = [(minX + maxX) / 2, (minY + maxY) / 2];
  if (_contains(commands, center)) return center;
  for (var y = minY; y <= maxY; y += math.max(1, (maxY - minY) / 12)) {
    for (var x = minX; x <= maxX; x += math.max(1, (maxX - minX) / 12)) {
      if (_contains(commands, [x, y])) return [x, y];
    }
  }
  return points.first;
}

List<List<double>> _points(List<ParsedCommand> commands) {
  final result = <List<double>>[];
  var x = 0.0, y = 0.0;
  for (final command in commands) {
    switch (command.command) {
      case 'M':
      case 'L':
        x = command.values[0];
        y = command.values[1];
        result.add([x, y]);
      case 'H':
        x = command.values[0];
        result.add([x, y]);
      case 'V':
        y = command.values[0];
        result.add([x, y]);
    }
  }
  return result;
}

bool _contains(List<ParsedCommand> commands, List<double> point) {
  final points = _points(commands);
  var inside = false;
  for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
    final a = points[i], b = points[j];
    if ((a[1] > point[1]) != (b[1] > point[1]) &&
        point[0] < (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0]) {
      inside = !inside;
    }
  }
  return inside;
}

void _writeMap(
  String path, {
  required String mapId,
  required List<int> viewBox,
  required List<_Entry> entries,
}) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln("import 'dart:ui';")
    ..writeln("import '../models.dart';")
    ..writeln()
    ..writeln(
      'final MapDefinition generated${mapId[0].toUpperCase()}${mapId.substring(1)} = MapDefinition(',
    )
    ..writeln("  id: '$mapId',")
    ..writeln('  viewBox: Size(${viewBox[0]}, ${viewBox[1]}),')
    ..writeln('  regions: <MapRegion>[');
  for (final entry in entries) {
    out.writeln('    MapRegion(');
    out.writeln("      id: '${entry.id}',");
    out.writeln("      name: '${entry.name}',");
    out.writeln('      geometry: MapGeometry(const <MapPathCommand>[');
    for (final command in entry.commands) {
      final values = command.values.map((value) => _number(value)).join(', ');
      switch (command.command) {
        case 'M':
          out.writeln('        MapPathCommand.move($values),');
        case 'L':
          out.writeln('        MapPathCommand.line($values),');
        case 'H':
          out.writeln('        MapPathCommand.horizontal($values),');
        case 'V':
          out.writeln('        MapPathCommand.vertical($values),');
        case 'Z':
          out.writeln('        MapPathCommand.close(),');
      }
    }
    out.writeln('      ]),');
    out.writeln(
      '      markerAnchor: Offset(${_number(entry.anchor[0])}, ${_number(entry.anchor[1])}),',
    );
    out.writeln('    ),');
  }
  out.writeln('  ],\n);');
  final file = File(path)..createSync(recursive: true);
  file.writeAsStringSync(out.toString());
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class _Entry {
  _Entry(this.id, this.name, this.commands, this.anchor);
  final String id;
  final String name;
  final List<ParsedCommand> commands;
  final List<double> anchor;
}
