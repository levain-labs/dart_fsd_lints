import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:feature_sliced_lints/src/fsd.dart';

/// Slices on the same layer can't import each other. The only exception is
/// the FSD v2.1 `@x` notation, reproduced as a folder convention
/// (`<layer>/<other>/@x/<me>.dart`).
///
/// The correction can be replaced per layer with `fsd.cross_slice_hints`
/// (e.g. pages that should navigate through a router instead).
class FsdNoCrossSlice extends AnalysisRule {
  static const LintCode code = LintCode(
    'fsd_no_cross_slice',
    "Can't import the slice '{1}' on the same '{0}' layer.",
    correctionMessage: '{2}',
  );

  FsdNoCrossSlice()
    : super(
        name: 'fsd_no_cross_slice',
        description:
            'Slices on the same layer may only import each other via @x.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // Resolved once per file, not per directive.
    final FsdContext? fsd = FsdContext.of(context);
    if (fsd == null || fsd.source == null) return;
    final _Visitor visitor = _Visitor(this, fsd);
    registry
      ..addImportDirective(this, visitor)
      ..addExportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.fsd);

  final AnalysisRule rule;
  final FsdContext fsd;

  @override
  void visitImportDirective(ImportDirective node) => _check(node);

  @override
  void visitExportDirective(ExportDirective node) => _check(node);

  void _check(NamespaceDirective node) {
    final FsdLocation? source = fsd.source;
    final FsdLocation? target = fsd.targetOf(node);
    final String? sourceSlice = source?.slice;
    final String? targetSlice = target?.slice;
    if (source == null ||
        target == null ||
        sourceSlice == null ||
        targetSlice == null ||
        source.layer != target.layer ||
        sourceSlice == targetSlice) {
      return;
    }
    if (target.isCrossImportFor(sourceSlice)) return;
    final String correction =
        fsd.config.crossSliceHints[source.layer] ??
        "Move the shared code to a lower layer, or import it via "
            "'${target.slicePath}/@x/$sourceSlice.dart'.";
    rule.reportAtNode(
      node.uri,
      arguments: [source.layer, targetSlice, correction],
    );
  }
}
