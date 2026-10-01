import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:feature_sliced_lints/src/fsd.dart';

/// FSD layers may only import downward
/// (app → pages → widgets → features → entities → shared by default).
class FsdLayerImports extends AnalysisRule {
  static const LintCode code = LintCode(
    'fsd_layer_imports',
    "The '{0}' layer can't import from the higher '{1}' layer.",
    correctionMessage:
        'Move the dependency down to a lower layer, or pass it in from above '
        '(e.g. as a callback).',
  );

  FsdLayerImports()
    : super(
        name: 'fsd_layer_imports',
        description: 'FSD layers may only import downward.',
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
    if (source == null || target == null) return;
    if (target.rank < source.rank) {
      rule.reportAtNode(node.uri, arguments: [source.layer, target.layer]);
    }
  }
}
