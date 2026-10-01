// test_reflective_loader finds tests by the test_ method name prefix.
// ignore_for_file: non_constant_identifier_names

import 'package:fsd_lints/src/fixes/use_barrel_import.dart';
import 'package:fsd_lints/src/lint_config.dart';
import 'package:fsd_lints/src/rules/fsd_public_api.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support/fix_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UseBarrelImportTest);
  });

  group('barrelUriFor', () {
    test('points into the slice barrel', () {
      expect(
        barrelUriFor('package:app/entities/user/domain/user.dart', FsdConfig()),
        'package:app/entities/user/user.dart',
      );
    });

    test('respects root and index barrels', () {
      expect(
        barrelUriFor(
          'package:app/src/features/auth/ui/login.dart',
          FsdConfig(root: 'lib/src', barrel: BarrelStyle.indexFile),
        ),
        'package:app/src/features/auth/index.dart',
      );
    });

    test('is null outside slices', () {
      expect(barrelUriFor('package:app/shared/clock.dart', FsdConfig()), null);
      expect(barrelUriFor('dart:async', FsdConfig()), null);
    });
  });
}

@reflectiveTest
class UseBarrelImportTest extends AnalysisRuleFixTest {
  @override
  FixProducerFactory get producerFactory => UseBarrelImport.new;

  @override
  void setUp() {
    rule = FsdPublicApi();
    super.setUp();
    newFile('$testPackageLibPath/entities/maker/maker.dart', 'class M {}');
    newFile('$testPackageLibPath/entities/maker/domain/maker.dart', '');
  }

  Future<void> test_rewritesToBarrel() async {
    await assertHasFix(
      'features/print/x.dart',
      "export 'package:test/entities/maker/domain/maker.dart';\n",
      "export 'package:test/entities/maker/maker.dart';\n",
    );
    expect(lastProducer.fixArguments, [
      'package:test/entities/maker/maker.dart',
    ]);
  }

  Future<void> test_keepsQuoteStyle() async {
    await assertHasFix(
      'features/print/x.dart',
      'export "package:test/entities/maker/domain/maker.dart";\n',
      'export "package:test/entities/maker/maker.dart";\n',
    );
  }

  Future<void> test_indexBarrel() async {
    newFile(
      '$testPackageRootPath/$lintConfigFileName',
      'fsd:\n  barrel: index\n',
    );
    newFile('$testPackageLibPath/entities/maker/index.dart', 'class M {}');
    await assertHasFix(
      'features/print/x.dart',
      "export 'package:test/entities/maker/domain/maker.dart';\n",
      "export 'package:test/entities/maker/index.dart';\n",
    );
  }
}
