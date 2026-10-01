import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analysis_server_plugin/edit/fix/fix.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:fsd_lints/src/fsd.dart';
import 'package:fsd_lints/src/lint_config.dart';

/// The fix for `fsd_public_api`: points the import/export at the slice's
/// barrel file instead of its internal file.
///
/// Plugin fixes can't be applied in bulk (`dart fix`), so this is offered one
/// location at a time in the IDE. The barrel may not export the symbol yet;
/// the user decides whether it should.
class UseBarrelImport extends ResolvedCorrectionProducer {
  UseBarrelImport({required super.context});

  static const FixKind kind = FixKind(
    'fsd_lints.fix.useBarrelImport',
    DartFixKindPriority.standard,
    "Import through the barrel file '{0}'",
  );

  String _barrelUri = '';

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => kind;

  @override
  List<String> get fixArguments => [_barrelUri];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? literal = coveringNode;
    if (literal is! SimpleStringLiteral ||
        literal.parent is! NamespaceDirective) {
      return;
    }
    final String? barrelUri = barrelUriFor(
      literal.value,
      LintConfig.forPackageRoot(packageRootOf(unitResult.file)).fsd,
    );
    if (barrelUri == null) return;
    _barrelUri = barrelUri;
    final String quote = literal.isSingleQuoted ? "'" : '"';
    await builder.addDartFileEdit(file, (DartFileEditBuilder builder) {
      builder.addSimpleReplacement(
        SourceRange(literal.offset, literal.length),
        '$quote$barrelUri$quote',
      );
    });
  }
}

/// The `package:` URI of the barrel file of the slice that [uri] points into,
/// or `null` when [uri] isn't inside a slice.
String? barrelUriFor(String uri, FsdConfig config) {
  if (!uri.startsWith('package:')) return null;
  final List<String> segments = uri.substring('package:'.length).split('/');
  if (segments.length < 2) return null;
  final FsdLocation? target = FsdLocation.parse(
    config,
    segments.skip(1).join('/'),
  );
  final String? barrel = target?.barrelPath;
  if (barrel == null) return null;
  return 'package:${segments.first}/$barrel';
}
