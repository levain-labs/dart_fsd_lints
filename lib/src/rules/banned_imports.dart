import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';

/// Bans imports/exports whose URI starts with an entry of `banned_imports`
/// in `feature_sliced_lints.yaml`. Applies to both lib/ and test/.
///
/// A generic rule for packages a project has decided not to use (e.g. code
/// generators or mocking libraries).
class BannedImports extends AnalysisRule {
  static const LintCode code = LintCode(
    'banned_imports',
    "'{0}' is banned in this project.",
    correctionMessage: '{1}',
  );

  BannedImports()
    : super(
        name: 'banned_imports',
        description:
            'Disallows imports/exports banned in feature_sliced_lints.yaml.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final List<BannedImport> banned = LintConfig.of(context).bannedImports;
    if (banned.isEmpty) return;
    final _Visitor visitor = _Visitor(this, banned);
    registry
      ..addImportDirective(this, visitor)
      ..addExportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.banned);

  final AnalysisRule rule;
  final List<BannedImport> banned;

  @override
  void visitImportDirective(ImportDirective node) => _check(node);

  @override
  void visitExportDirective(ExportDirective node) => _check(node);

  void _check(NamespaceDirective node) {
    final String? uri = node.uri.stringValue;
    if (uri == null) return;
    for (final BannedImport entry in banned) {
      if (uri.startsWith(entry.uriPrefix)) {
        rule.reportAtNode(node.uri, arguments: [uri, entry.reason]);
        return;
      }
    }
  }
}
