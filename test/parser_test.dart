import 'package:flutter_test/flutter_test.dart';

import '../tool/svg_path_parser.dart';

void main() {
  group('SvgPathParser', () {
    test('parses absolute commands, repeated coordinates and subpaths', () {
      final commands = SvgPathParser.parse('M0 0 10 0H20V30L5 5Z M1.5,2.5Z');
      expect(commands.map((command) => command.command), [
        'M',
        'L',
        'H',
        'V',
        'L',
        'Z',
        'M',
        'Z',
      ]);
      expect(commands[1].values, [10, 0]);
      expect(commands[6].values, [1.5, 2.5]);
    });

    test('rejects relative and curve commands', () {
      expect(() => SvgPathParser.parse('m0 0l1 1'), throwsFormatException);
      expect(
        () => SvgPathParser.parse('M0 0C1 1 2 2 3 3'),
        throwsFormatException,
      );
    });
  });
}
