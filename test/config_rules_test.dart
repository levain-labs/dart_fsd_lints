// test_reflective_loader finds tests by the test_ method name prefix.
// ignore_for_file: non_constant_identifier_names

// To expect the unresolved URI error of the test environment (the same
// import analyzer_testing itself uses).
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';
import 'package:feature_sliced_lints/src/rules/domain_purity.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DomainPurityTest);
  });

  group('LintConfig.parse', () {
    test('an empty file means the defaults', () {
      final LintConfig config = LintConfig.parse('');
      expect(config.domainPurity, isNull);
      expect(config.fsd.root, 'lib');
      expect(config.fsd.layers, FsdConfig.defaultLayers);
      expect(config.fsd.slicedLayers, {
        'pages',
        'widgets',
        'features',
        'entities',
      });
      expect(config.fsd.barrel, BarrelStyle.sliceName);
    });

    test('domain_purity.directory defaults to domain', () {
      final LintConfig config = LintConfig.parse('domain_purity: {}');
      expect(config.domainPurity?.directoryName, 'domain');
      expect(config.domainPurity?.allowedPackages, isEmpty);
    });

    test('sliced layers default to all but the first and the last', () {
      final LintConfig config = LintConfig.parse(
        'fsd:\n  layers: [app, processes, pages, shared]\n',
      );
      expect(config.fsd.slicedLayers, {'processes', 'pages'});
    });

    test('barrel accepts index', () {
      final LintConfig config = LintConfig.parse('fsd:\n  barrel: index\n');
      expect(config.fsd.barrelFileOf('user'), 'index.dart');
    });

    for (final (String name, String yaml) in [
      ('root outside lib', 'fsd:\n  root: src\n'),
      ('duplicate layers', 'fsd:\n  layers: [a, a]\n'),
      ('unknown sliced layer', 'fsd:\n  sliced_layers: [nope]\n'),
      ('unknown barrel style', 'fsd:\n  barrel: main\n'),
      ('non-string package', 'domain_purity:\n  allowed_packages: [1]\n'),
    ]) {
      test('rejects $name', () {
        expect(() => LintConfig.parse(yaml), throwsFormatException);
      });
    }
  });
}

/// Writes the config file at the root of the test package (named `test`).
mixin _ConfigFixture on AnalysisRuleTest {
  void writeConfig(String yaml) {
    newFile('$testPackageRootPath/$lintConfigFileName', yaml);
  }

  /// Writes [content] to [path] and returns its absolute path.
  String libFile(String path, String content) {
    newFile('$testPackageLibPath/$path', content);
    return '$testPackageLibPath/$path';
  }
}

@reflectiveTest
class DomainPurityTest extends AnalysisRuleTest with _ConfigFixture {
  @override
  void setUp() {
    newPackage('flutter').addFile('lib/foundation.dart', 'class Key {}');
    newPackage('meta').addFile('lib/meta.dart', 'class Immutable {}');
    rule = DomainPurity();
    super.setUp();
    newFile('$testPackageLibPath/shared/clock.dart', 'class Clock {}');
    writeConfig('''
domain_purity:
  allowed_packages: [meta]
''');
  }

  Future<void> test_flutterInDomain_isReported() async {
    await assertDiagnosticsInFile(
      libFile(
        'entities/product/domain/product.dart',
        "export 'package:flutter/foundation.dart';\n",
      ),
      [lint(7, 33)],
    );
  }

  Future<void> test_dartUiInDomain_isReported() async {
    await assertDiagnosticsInFile(
      libFile('features/print/domain/x.dart', "export 'dart:ui';\n"),
      // dart:ui doesn't exist in the test environment, so the URI is also
      // reported as unresolved.
      [error(diag.uriDoesNotExist, 7, 9), lint(7, 9)],
    );
  }

  Future<void> test_allowedAndOwnAndDart_areAllowed() async {
    await assertDiagnosticsInFile(
      libFile('features/print/domain/x.dart', r'''
export 'dart:async';
export 'package:meta/meta.dart';
export 'package:test/shared/clock.dart';
'''),
      [],
    );
  }

  Future<void> test_outsideDomain_isNotChecked() async {
    await assertDiagnosticsInFile(
      libFile(
        'entities/product/data/x.dart',
        "export 'package:flutter/foundation.dart';\n",
      ),
      [],
    );
  }
}
