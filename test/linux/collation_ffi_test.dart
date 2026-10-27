import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_natural_sort/src/linux/collation_ffi.dart';

void main() {
  group('IcuCollationLinuxRules', () {
    late IcuCollationLinuxRules rules;

    setUp(() {
      rules = IcuCollationLinuxRules();
    });

    test('recommendedVersion is 72', () {
      expect(IcuCollationLinuxRules.recommendedVersion, 72);
    });

    test('multiarchTriplet is a non-empty string', () {
      expect(rules.multiarchTriplet, isNotEmpty);
    });

    test('searchDirs includes standard multiarch paths', () {
      final dirs = rules.searchDirs;
      expect(dirs.any((d) => d.contains(rules.multiarchTriplet)), isTrue);
      expect(dirs.contains('/app/lib'), isTrue);
    });

    group('extractVersionMajor', () {
      test('extracts major version from soname path', () {
        expect(rules.extractVersionMajor('/usr/lib/libicui18n.so.72'), 72);
        expect(rules.extractVersionMajor('/lib/libicui18n.so.74.1'), 74);
        expect(rules.extractVersionMajor('libicui18n.so.70'), 70);
      });

      test('returns null for unversioned soname', () {
        expect(rules.extractVersionMajor('/usr/lib/libicui18n.so'), isNull);
        expect(rules.extractVersionMajor('libicui18n.so'), isNull);
      });

      test('returns null for unrelated paths', () {
        expect(rules.extractVersionMajor('/usr/lib/libc.so.6'), isNull);
        expect(rules.extractVersionMajor(''), isNull);
      });
    });

    group('extractVersionSuffix', () {
      test('produces underscore-prefixed suffix', () {
        expect(rules.extractVersionSuffix('libicui18n.so.72'), '_72');
        expect(rules.extractVersionSuffix('libicui18n.so.74'), '_74');
      });

      test('returns empty string for unversioned', () {
        expect(rules.extractVersionSuffix('libicui18n.so'), '');
      });
    });

    group('candidates', () {
      test('always includes unversioned and recommended version', () {
        final result = rules.candidates([]);
        expect(result, ['libicui18n.so', 'libicui18n.so.72']);
      });

      test('prepends highest discovered version', () {
        final result = rules.candidates([
          'libicui18n.so.75',
          'libicui18n.so.74',
        ]);
        expect(result, [
          'libicui18n.so',
          'libicui18n.so.72',
          'libicui18n.so.75',
        ]);
      });

      test('single discovered version is appended after recommended', () {
        final result = rules.candidates(['libicui18n.so.70']);
        expect(result, [
          'libicui18n.so',
          'libicui18n.so.72',
          'libicui18n.so.70',
        ]);
      });

      test('duplicate of recommended version is not deduped', () {
        final result = rules.candidates(['libicui18n.so.72']);
        expect(result, [
          'libicui18n.so',
          'libicui18n.so.72',
          'libicui18n.so.72',
        ]);
      });
    });

    test('unversioned soname resolves to a usable suffix', () {
      final (lib, suffix) = rules.tryLoadPath('libicui18n.so')!;
      expect(lib.providesSymbol('ucol_open$suffix'), isTrue);
    }, skip: _canOpen('libicui18n.so') ? false : 'libicui18n.so not loadable');
  });
}

bool _canOpen(String path) {
  try {
    DynamicLibrary.open(path);
    return true;
  } catch (_) {
    return false;
  }
}
