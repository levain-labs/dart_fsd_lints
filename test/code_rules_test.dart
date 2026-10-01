// test_reflective_loader finds tests by the test_ method name prefix.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';
import 'package:feature_sliced_lints/src/rules/no_direct_datetime_now.dart';
import 'package:feature_sliced_lints/src/rules/no_direct_debug_print.dart';
import 'package:feature_sliced_lints/src/rules/presentational_purity.dart';
import 'package:feature_sliced_lints/src/rules/provider_declaration_location.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoDirectDatetimeNowTest);
    defineReflectiveTests(NoDirectDebugPrintTest);
    defineReflectiveTests(ProviderDeclarationLocationTest);
    defineReflectiveTests(PresentationalPurityTest);
  });
}

@reflectiveTest
class NoDirectDatetimeNowTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoDirectDatetimeNow();
    super.setUp();
  }

  Future<void> test_now_isReported() async {
    await assertDiagnostics(
      r'''
final DateTime t = DateTime.now();
''',
      [lint(19, 14)],
    );
  }

  Future<void> test_userDefinedNow_isAllowed() async {
    await assertNoDiagnostics(r'''
class Clock {
  Clock.now();
}
final Clock c = Clock.now();
''');
  }
}

@reflectiveTest
class NoDirectDebugPrintTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('flutter').addFile('lib/foundation.dart', r'''
typedef DebugPrintCallback = void Function(String? message, {int? wrapWidth});
DebugPrintCallback debugPrint = (String? message, {int? wrapWidth}) {};
''');
    rule = NoDirectDebugPrint();
    super.setUp();
  }

  Future<void> test_print_isReported() async {
    await assertDiagnostics(
      r'''
void f() {
  print('x');
}
''',
      [lint(13, 5)],
    );
  }

  Future<void> test_debugPrint_isReported() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/foundation.dart';
void f() {
  debugPrint('x');
}
''',
      [lint(55, 10)],
    );
  }

  Future<void> test_showCombinator_isNotACall() async {
    await assertNoDiagnostics(r'''
// ignore_for_file: unused_import
import 'package:flutter/foundation.dart' show debugPrint;
''');
  }

  Future<void> test_tearOff_isReported() async {
    await assertDiagnostics(
      r'''
void f(List<String> xs) {
  xs.forEach(print);
}
''',
      [lint(39, 5)],
    );
  }

  Future<void> test_ownPrintMethod_isAllowed() async {
    await assertNoDiagnostics(r'''
class Logger {
  void print(String s) {}
}
void f(Logger l) {
  l.print('x');
}
''');
  }
}

@reflectiveTest
class ProviderDeclarationLocationTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('riverpod').addFile('lib/riverpod.dart', r'''
sealed class ProviderOrFamily {}
class Provider<T> extends ProviderOrFamily {
  Provider(T Function(Object ref) create);
}
class Family extends ProviderOrFamily {}
''');
    rule = ProviderDeclarationLocation();
    super.setUp();
  }

  static const String _source = r'''
import 'package:riverpod/riverpod.dart';
final Provider<int> countProvider = Provider<int>((ref) => 0);
final Family byIdProvider = Family();
final int notAProvider = 0;
''';

  Future<void> test_outsideProvidersFile_isReported() async {
    newFile('$testPackageLibPath/features/x/x_sync.dart', _source);
    await assertDiagnosticsInFile(
      '$testPackageLibPath/features/x/x_sync.dart',
      [lint(61, 13), lint(117, 12)],
    );
  }

  Future<void> test_inProvidersFile_isAllowed() async {
    newFile('$testPackageLibPath/features/x/x_providers.dart', _source);
    await assertNoDiagnosticsInFile(
      '$testPackageLibPath/features/x/x_providers.dart',
    );
  }

  Future<void> test_customSuffix_isRespected() async {
    newFile(
      '$testPackageRootPath/$lintConfigFileName',
      'provider_declaration_location:\n  file_suffix: _di.dart\n',
    );
    newFile('$testPackageLibPath/features/x/x_di.dart', _source);
    newFile('$testPackageLibPath/features/x/x_providers.dart', _source);
    await assertNoDiagnosticsInFile('$testPackageLibPath/features/x/x_di.dart');
    await assertDiagnosticsInFile(
      '$testPackageLibPath/features/x/x_providers.dart',
      [lint(61, 13), lint(117, 12)],
    );
  }
}

@reflectiveTest
class PresentationalPurityTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('flutter_riverpod').addFile('lib/flutter_riverpod.dart', '');
    newPackage('cloud_firestore').addFile('lib/cloud_firestore.dart', '');
    newPackage('flutter').addFile('lib/widgets.dart', '');
    rule = PresentationalPurity();
    super.setUp();
    newFile('$testPackageRootPath/$lintConfigFileName', '''
presentational_purity:
  forbidden_packages: [flutter_riverpod, cloud_firestore]
''');
  }

  // Written as imports (this rule only looks at imports), with the unused
  // import warnings suppressed.
  static const String _source = r'''
// ignore_for_file: unused_import
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
''';

  Future<void> test_viewFile_isReported() async {
    newFile('$testPackageLibPath/pages/x/x_view.dart', _source);
    await assertDiagnosticsInFile('$testPackageLibPath/pages/x/x_view.dart', [
      lint(80, 48),
      lint(137, 46),
    ]);
  }

  Future<void> test_noForbiddenPackages_isSilent() async {
    newFile('$testPackageRootPath/$lintConfigFileName', '');
    newFile('$testPackageLibPath/pages/x/x_view.dart', _source);
    await assertNoDiagnosticsInFile('$testPackageLibPath/pages/x/x_view.dart');
  }

  Future<void> test_customSuffix_isRespected() async {
    newFile('$testPackageRootPath/$lintConfigFileName', '''
presentational_purity:
  file_suffix: _widget.dart
  forbidden_packages: [cloud_firestore]
''');
    newFile('$testPackageLibPath/pages/x/x_widget.dart', _source);
    await assertDiagnosticsInFile('$testPackageLibPath/pages/x/x_widget.dart', [
      lint(137, 46),
    ]);
  }

  Future<void> test_screenFile_isAllowed() async {
    newFile('$testPackageLibPath/pages/x/x_screen.dart', _source);
    await assertNoDiagnosticsInFile(
      '$testPackageLibPath/pages/x/x_screen.dart',
    );
  }
}
