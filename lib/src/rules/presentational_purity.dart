import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';

/// Presentational files (`*_view.dart` by default) don't know about state
/// management, persistence or analytics: they must not import the packages
/// listed in `presentational_purity.forbidden_packages`.
class PresentationalPurity extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentational_purity',
    "Presentational files can't import '{0}'.",
    correctionMessage:
        'Receive data and callbacks from the container widget instead.',
  );

  PresentationalPurity()
    : super(
        name: 'presentational_purity',
        description:
            'Presentational files do not import state management, '
            'persistence or analytics packages.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final PresentationalPurityConfig config = LintConfig.of(
      context,
    ).presentationalPurity;
    if (config.forbiddenPackages.isEmpty) return;
    registry.addImportDirective(this, _Visitor(this, context, config));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context, this.config);

  final AnalysisRule rule;
  final RuleContext context;
  final PresentationalPurityConfig config;

  @override
  void visitImportDirective(ImportDirective node) {
    final String? fileName = context.currentUnit?.file.shortName;
    if (fileName == null || !fileName.endsWith(config.fileSuffix)) return;
    final String? uri = node.uri.stringValue;
    if (uri == null || !uri.startsWith('package:')) return;
    final String package = uri.substring('package:'.length).split('/').first;
    if (config.forbiddenPackages.contains(package)) {
      rule.reportAtNode(node.uri, arguments: [package]);
    }
  }
}
