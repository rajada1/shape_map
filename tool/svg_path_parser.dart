/// A parsed absolute SVG path command used by the offline generator.
class ParsedCommand {
  const ParsedCommand(this.command, this.values);

  final String command;
  final List<double> values;
}

/// Minimal parser for the absolute SVG commands supported by shape_map.
class SvgPathParser {
  static const _supported = {'M', 'L', 'H', 'V', 'Z'};

  /// Parses absolute M/L/H/V/Z commands, including repeated coordinate sets.
  static List<ParsedCommand> parse(String input) {
    final scanner = _Scanner(input);
    final result = <ParsedCommand>[];
    var command = '';
    while (!scanner.done) {
      final token = scanner.nextToken();
      Object valueToken = token;
      if (token is String) {
        command = token;
        if (!_supported.contains(command)) {
          throw FormatException('Unsupported SVG path command: $command');
        }
        if (command == 'Z') {
          result.add(const ParsedCommand('Z', <double>[]));
          command = '';
          continue;
        }
        valueToken = scanner.nextToken();
      } else if (command.isEmpty) {
        throw const FormatException('Path coordinates require a command');
      }
      if (valueToken is! double) {
        throw const FormatException(
          'Path commands require numeric coordinates',
        );
      }
      final count = command == 'H' || command == 'V' ? 1 : 2;
      final values = <double>[valueToken];
      while (values.length < count) {
        final next = scanner.nextToken();
        if (next is! double) {
          throw const FormatException('Incomplete SVG path command');
        }
        values.add(next);
      }
      result.add(ParsedCommand(command, values));
      if (command == 'M') command = 'L';
    }
    return result;
  }
}

class _Scanner {
  _Scanner(this.source);
  final String source;
  int index = 0;
  bool get done => _skipSeparators() >= source.length;

  Object nextToken() {
    _skipSeparators();
    if (index >= source.length) {
      throw const FormatException('Unexpected end of path');
    }
    final char = source[index];
    if (RegExp(r'[A-Za-z]').hasMatch(char)) {
      index++;
      return char;
    }
    final match = RegExp(
      r'[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?',
    ).matchAsPrefix(source, index);
    if (match == null) throw FormatException('Invalid path token at $index');
    index = match.end;
    return double.parse(match.group(0)!);
  }

  int _skipSeparators() {
    while (index < source.length &&
        (source[index] == ',' || source[index].trim().isEmpty)) {
      index++;
    }
    return index;
  }
}
