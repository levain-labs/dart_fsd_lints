import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';

/// Creates a fix for a resolved context (e.g. `UseBarrelImport.new`).
typedef FixProducerFactory =
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    });

/// A base for testing quick fixes. `analyzer_testing` only covers rules, so
/// this resolves the file, builds the fix context for the rule's diagnostic,
/// and applies the produced edits.
abstract class AnalysisRuleFixTest extends AnalysisRuleTest {
  FixProducerFactory get producerFactory;

  /// Writes [content] to [path] (relative to `lib/`), applies the fix to the
  /// first diagnostic of [rule], and expects [expected].
  Future<void> assertHasFix(
    String path,
    String content,
    String expected,
  ) async {
    final ResolvedCorrectionProducer producer = await _produce(path, content);
    expect(await _apply(producer, content), expected);
  }

  /// Like [assertHasFix], but expects the fix to produce no edits.
  Future<void> assertNoFix(String path, String content) async {
    final ResolvedCorrectionProducer producer = await _produce(path, content);
    expect(await _apply(producer, content), content);
  }

  /// The producer of the last [assertHasFix] / [assertNoFix] call, for
  /// checking things like `fixArguments`.
  late ResolvedCorrectionProducer lastProducer;

  Future<ResolvedCorrectionProducer> _produce(
    String path,
    String content,
  ) async {
    final String filePath = '$testPackageLibPath/$path';
    newFile(filePath, content);
    result = await resolveFile(filePath);
    final Diagnostic diagnostic = result.diagnostics.firstWhere(
      (Diagnostic d) => d.diagnosticCode.lowerCaseName == rule.name,
      orElse: () => fail('${rule.name} was not reported in $path'),
    );
    final ResolvedLibraryResult library =
        await result.session.getResolvedLibrary(filePath)
            as ResolvedLibraryResult;
    return lastProducer = producerFactory(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: result,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
        selectionLength: diagnostic.length,
      ),
    );
  }

  Future<String> _apply(
    ResolvedCorrectionProducer producer,
    String content,
  ) async {
    final ChangeBuilder builder = ChangeBuilder(session: result.session);
    await producer.compute(builder);
    String fixed = content;
    for (final fileEdit in builder.sourceChange.edits) {
      // Apply from the end so earlier offsets stay valid.
      final edits = [...fileEdit.edits]
        ..sort((a, b) => b.offset.compareTo(a.offset));
      for (final edit in edits) {
        fixed = fixed.replaceRange(
          edit.offset,
          edit.offset + edit.length,
          edit.replacement,
        );
      }
    }
    return fixed;
  }
}
