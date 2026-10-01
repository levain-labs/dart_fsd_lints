import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:fsd_lints/src/fsd.dart';

/// Outside a slice, import it only through its barrel file
/// (`<layer>/<slice>/<slice>.dart`, or `index.dart`). `@x` entry points on the
/// same layer are allowed, consistently with [FsdNoCrossSlice].
class FsdPublicApi extends AnalysisRule {
  static const LintCode code = LintCode(
    'fsd_public_api',
    "Importing an internal file of the slice '{0}'.",
    correctionMessage: "Import it through the barrel file '{1}'.",
  );

  FsdPublicApi()
    : super(
        name: 'fsd_public_api',
        description: 'Import slices only through their barrel files.',
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
    if (fsd == null) return;
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
    final FsdLocation? target = fsd.targetOf(node);
    final String? targetSlice = target?.slice;
    if (target == null || targetSlice == null) return;
    final FsdLocation? source = fsd.source;
    if (source != null && source.isSameSliceAs(target)) return;
    if (target.isBarrel) return;
    final String? sourceSlice = source?.slice;
    if (source != null &&
        sourceSlice != null &&
        source.layer == target.layer &&
        target.isCrossImportFor(sourceSlice)) {
      return;
    }
    rule.reportAtNode(
      node.uri,
      arguments: [
        target.slicePath,
        '${target.slicePath}/${fsd.config.barrelFileOf(targetSlice)}',
      ],
    );
  }
}
