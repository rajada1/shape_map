// Offline map generation entry point.
import 'dart:io';

void main() {
  final node = _findNode();
  final nodeModules = Directory('tool/node_modules');
  if (!nodeModules.existsSync()) {
    final install = Process.runSync('npm', [
      'ci',
      '--prefix',
      'tool',
    ], runInShell: true);
    stdout.write(install.stdout);
    stderr.write(install.stderr);
    if (install.exitCode != 0) {
      throw ProcessException(
        'npm',
        ['ci', '--prefix', 'tool'],
        install.stderr,
        install.exitCode,
      );
    }
  }
  final result = Process.runSync(node, [
    'tool/maps/build.mjs',
  ], runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      node,
      ['tool/maps/build.mjs'],
      result.stderr,
      result.exitCode,
    );
  }
}

String _findNode() {
  for (final executable in ['node', 'nodejs']) {
    final result = Process.runSync(executable, ['--version'], runInShell: true);
    if (result.exitCode == 0) return executable;
  }
  throw StateError('Node.js is required to generate shape_map data.');
}
