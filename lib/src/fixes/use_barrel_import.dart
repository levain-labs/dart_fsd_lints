import 'package:analysis_server_plugin/edit/change_builder/change_builder.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analysis_server_plugin/edit/fix/fix.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:feature_sliced_lints/src/fsd.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';

/// The fix for `fsd_public_api`: points the import/export at the slice's
/// barrel file instead of its internal file.
///
/// Plugin fixes can't be applied in bulk (`dart fix`), so this is offered one
/// location at a time in the IDE. The barrel may not export the symbol yet;
/// the user decides whether it should.
class UseBarrelImport extends ResolvedCorrectionProducer {
  UseBarrelImport({required super.context});

  static const FixKind kind = FixKind(
    'feature_sliced_lints.fix.useBarrelImport',
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
      unitResult.libraryElement.uri,
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

/// The URI of the barrel file of the slice that [uri] points into, or `null`
/// when [uri] isn't inside a slice. [uri] is written in the file at
/// [sourceUri]; a relative [uri] gets a relative barrel URI, a `package:` one
/// a `package:` URI.
String? barrelUriFor(String uri, FsdConfig config, Uri sourceUri) {
  final Uri? target = resolveDirectiveUri(sourceUri, uri);
  if (target == null ||
      !target.isScheme('package') ||
      target.pathSegments.isEmpty) {
    return null;
  }
  final String packageName = target.pathSegments.first;
  final String? libRelativePath = libRelativePathOf(packageName, target);
  if (libRelativePath == null) return null;
  final String? barrel = FsdLocation.parse(config, libRelativePath)?.barrelPath;
  if (barrel == null) return null;
  final Uri barrelUri = Uri(scheme: 'package', path: '$packageName/$barrel');
  return Uri.parse(uri).hasScheme
      ? barrelUri.toString()
      : _relativeUri(sourceUri, barrelUri);
}

/// [to] relative to the directory of [from] (both `package:` URIs of the same
/// package).
String _relativeUri(Uri from, Uri to) {
  final List<String> fromDir = [...from.pathSegments]..removeLast();
  final List<String> toSegments = to.pathSegments;
  int common = 0;
  while (common < fromDir.length &&
      common < toSegments.length - 1 &&
      fromDir[common] == toSegments[common]) {
    common++;
  }
  return [
    for (int i = common; i < fromDir.length; i++) '..',
    ...toSegments.skip(common),
  ].join('/');
}
