// test_reflective_loader finds tests by the test_ method name prefix.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:fsd_lints/src/lint_config.dart';
import 'package:fsd_lints/src/rules/fsd_layer_imports.dart';
import 'package:fsd_lints/src/rules/fsd_no_cross_slice.dart';
import 'package:fsd_lints/src/rules/fsd_public_api.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FsdLayerImportsTest);
    defineReflectiveTests(FsdNoCrossSliceTest);
    defineReflectiveTests(FsdPublicApiTest);
  });
}

/// Puts an FSD skeleton under `lib/` of the test package (named `test`).
/// Imports and exports go through the same check, so the sources use exports
/// to avoid unused import warnings (same length, too).
mixin _FsdFixture on AnalysisRuleTest {
  void writeLib(String path, [String content = '']) {
    newFile('$testPackageLibPath/$path', content);
  }

  void writeConfig(String yaml) {
    newFile('$testPackageRootPath/$lintConfigFileName', yaml);
  }

  void writeSkeleton() {
    writeLib('shared/shared.dart', 'class S {}');
    writeLib('entities/maker/maker.dart', 'class M {}');
    writeLib('entities/maker/domain/maker.dart', 'class MI {}');
    writeLib('entities/maker/@x/product.dart', 'class MX {}');
    writeLib('entities/product/product.dart', 'class P {}');
    writeLib('features/print/print.dart', 'class F {}');
    writeLib('pages/settings/settings.dart', 'class PS {}');
    writeLib('pages/settings/settings_screen.dart', 'class PSS {}');
    writeLib('app/arti_app.dart', 'class A {}');
  }

  /// Writes [content] to [path] and returns its absolute path.
  String libFile(String path, String content) {
    writeLib(path, content);
    return '$testPackageLibPath/$path';
  }
}

@reflectiveTest
class FsdLayerImportsTest extends AnalysisRuleTest with _FsdFixture {
  @override
  void setUp() {
    rule = FsdLayerImports();
    super.setUp();
    writeSkeleton();
  }

  Future<void> test_downward_isAllowed() async {
    await assertDiagnosticsInFile(
      libFile('pages/product_list/x.dart', r'''
export 'package:test/features/print/print.dart';
export 'package:test/shared/shared.dart';
'''),
      [],
    );
  }

  Future<void> test_upward_isReported() async {
    await assertDiagnosticsInFile(
      libFile('entities/product/x.dart', r'''
export 'package:test/features/print/print.dart';
'''),
      [lint(7, 40)],
    );
  }

  Future<void> test_upwardExport_isReported() async {
    await assertDiagnosticsInFile(
      libFile('shared/x.dart', r'''
export 'package:test/app/arti_app.dart';
'''),
      [lint(7, 32)],
    );
  }

  Future<void> test_customLayers_areRespected() async {
    writeConfig('fsd:\n  layers: [app, features, core]\n');
    writeLib('core/core.dart', 'class C {}');
    await assertDiagnosticsInFile(
      libFile('core/x.dart', r'''
export 'package:test/features/print/print.dart';
'''),
      [lint(7, 40)],
    );
  }

  Future<void> test_rootUnderLib_isRespected() async {
    writeConfig('fsd:\n  root: lib/src\n');
    writeLib('src/features/print/print.dart', 'class F {}');
    await assertDiagnosticsInFile(
      libFile('src/shared/x.dart', r'''
export 'package:test/src/features/print/print.dart';
'''),
      [lint(7, 44)],
    );
  }

  Future<void> test_outsideRoot_isIgnored() async {
    writeConfig('fsd:\n  root: lib/src\n');
    await assertDiagnosticsInFile(
      libFile('shared/x.dart', r'''
export 'package:test/app/arti_app.dart';
'''),
      [],
    );
  }

  Future<void> test_outsideLayers_isIgnored() async {
    await assertDiagnosticsInFile(
      libFile('main.dart', r'''
export 'package:test/app/arti_app.dart';
'''),
      [],
    );
  }
}

@reflectiveTest
class FsdNoCrossSliceTest extends AnalysisRuleTest with _FsdFixture {
  @override
  void setUp() {
    rule = FsdNoCrossSlice();
    super.setUp();
    writeSkeleton();
  }

  Future<void> test_otherSliceBarrel_isReported() async {
    await assertDiagnosticsInFile(
      libFile('entities/product/x.dart', r'''
export 'package:test/entities/maker/maker.dart';
'''),
      [lint(7, 40)],
    );
  }

  Future<void> test_crossImportForMe_isAllowed() async {
    await assertDiagnosticsInFile(
      libFile('entities/product/x.dart', r'''
export 'package:test/entities/maker/@x/product.dart';
'''),
      [],
    );
  }

  Future<void> test_crossImportForSomeoneElse_isReported() async {
    writeLib('entities/maker/@x/paper.dart', 'class MP {}');
    await assertDiagnosticsInFile(
      libFile('entities/product/x.dart', r'''
export 'package:test/entities/maker/@x/paper.dart';
'''),
      [lint(7, 43)],
    );
  }

  Future<void> test_crossSliceHint_replacesCorrection() async {
    writeConfig('''
fsd:
  cross_slice_hints:
    pages: Navigate through the router.
''');
    await assertDiagnosticsInFile(
      libFile('pages/product_list/x.dart', r'''
export 'package:test/pages/settings/settings.dart';
'''),
      [lint(7, 43, correctionContains: 'Navigate through the router.')],
    );
  }

  Future<void> test_otherLayers_suggestCrossImport() async {
    await assertDiagnosticsInFile(
      libFile('entities/product/x.dart', r'''
export 'package:test/entities/maker/maker.dart';
'''),
      [lint(7, 40, correctionContains: 'entities/maker/@x/product.dart')],
    );
  }

  Future<void> test_pagesAreSlicedToo() async {
    await assertDiagnosticsInFile(
      libFile('pages/product_list/x.dart', r'''
export 'package:test/pages/settings/settings.dart';
'''),
      [lint(7, 43)],
    );
  }

  Future<void> test_sameSlice_isAllowed() async {
    await assertDiagnosticsInFile(
      libFile('entities/maker/x.dart', r'''
export 'package:test/entities/maker/domain/maker.dart';
'''),
      [],
    );
  }

  Future<void> test_otherLayer_isNotThisRulesConcern() async {
    await assertDiagnosticsInFile(
      libFile('features/print/x.dart', r'''
export 'package:test/entities/maker/maker.dart';
'''),
      [],
    );
  }

  Future<void> test_sharedHasNoSlices() async {
    writeLib('shared/clock.dart', 'class C {}');
    await assertDiagnosticsInFile(
      libFile('shared/x.dart', r'''
export 'package:test/shared/clock.dart';
'''),
      [],
    );
  }
}

@reflectiveTest
class FsdPublicApiTest extends AnalysisRuleTest with _FsdFixture {
  @override
  void setUp() {
    rule = FsdPublicApi();
    super.setUp();
    writeSkeleton();
  }

  Future<void> test_barrel_isAllowed() async {
    await assertDiagnosticsInFile(
      libFile('features/print/x.dart', r'''
export 'package:test/entities/maker/maker.dart';
'''),
      [],
    );
  }

  Future<void> test_internalFile_isReported() async {
    await assertDiagnosticsInFile(
      libFile('features/print/x.dart', r'''
export 'package:test/entities/maker/domain/maker.dart';
'''),
      [lint(7, 47)],
    );
  }

  Future<void> test_internalFileFromOutsideLayers_isReported() async {
    await assertDiagnosticsInFile(
      libFile('main.dart', r'''
export 'package:test/pages/settings/settings_screen.dart';
'''),
      [lint(7, 50)],
    );
  }

  Future<void> test_indexBarrel_isRespected() async {
    writeConfig('fsd:\n  barrel: index\n');
    writeLib('entities/maker/index.dart', 'class MB {}');
    await assertDiagnosticsInFile(
      libFile('features/print/x.dart', r'''
export 'package:test/entities/maker/index.dart';
export 'package:test/entities/maker/maker.dart';
'''),
      [lint(56, 40, correctionContains: 'entities/maker/index.dart')],
    );
  }

  Future<void> test_sameSliceInternal_isAllowed() async {
    await assertDiagnosticsInFile(
      libFile('entities/maker/x.dart', r'''
export 'package:test/entities/maker/domain/maker.dart';
'''),
      [],
    );
  }

  Future<void> test_crossImportForMe_isAllowed() async {
    await assertDiagnosticsInFile(
      libFile('entities/product/x.dart', r'''
export 'package:test/entities/maker/@x/product.dart';
'''),
      [],
    );
  }

  Future<void> test_crossImportFromOtherLayer_isReported() async {
    await assertDiagnosticsInFile(
      libFile('features/product/x.dart', r'''
export 'package:test/entities/maker/@x/product.dart';
'''),
      [lint(7, 45)],
    );
  }

  Future<void> test_sharedFiles_areNotSlices() async {
    writeLib('shared/clock.dart', 'class C {}');
    await assertDiagnosticsInFile(
      libFile('features/print/x.dart', r'''
export 'package:test/shared/clock.dart';
'''),
      [],
    );
  }
}
