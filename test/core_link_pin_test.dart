import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Doc links into the core repo must point at the tag of the version the
/// pubspec names, so readers land on the docs of the exact core in use.
/// A core bump PR that forgets the links fails here.
void main() {
  test('core repo links carry the pubspec version tag', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final floor =
        RegExp(r'^  cellar: \^(\S+)$', multiLine: true).firstMatch(pubspec);
    expect(floor, isNotNull, reason: 'pubspec must carry cellar: ^<version>');
    final tag = 'v${floor!.group(1)}';

    final docs = <File>[
      File('README.md'),
      File('SECURITY.md'),
      ...Directory('docs')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
    ];
    final ref = RegExp('whuppi/cellar/(?:blob|tree)/([^/]+)/');
    for (final doc in docs) {
      for (final m in ref.allMatches(doc.readAsStringSync())) {
        expect(m.group(1), tag,
            reason: '${doc.path} links the core at "${m.group(1)}" — '
                'must be $tag (the pubspec version). Update the link when '
                'bumping the core dependency.');
      }
    }
  });
}
