import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:feature_sliced_lints/src/fsd.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';

/// Keeps the domain layer (`<root>/<layer>/<slice>/domain/`) pure Dart. It may
/// only import/export its own package, `dart:` libraries (except `dart:ui`)
/// and the packages listed in `domain_purity.allowed_packages`.
///
/// It is an allow list because a deny list would let any newly added
/// dependency through.
class DomainPurity extends AnalysisRule {
  static const LintCode code = LintCode(
    'domain_purity',
    "The domain layer can't import '{0}'.",
    correctionMessage:
        'Keep the domain layer pure Dart: move this code to a boundary such '
        'as data/, or add the package to domain_purity.allowed_packages.',
  );

  DomainPurity()
    : super(
        name: 'domain_purity',
        description:
            'The domain layer depends only on allowed packages and dart: '
            '(except dart:ui).',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final DomainPurityConfig? config = LintConfig.of(context).domainPurity;
    if (config == null) return;
    final FsdContext? fsd = FsdContext.of(context);
    final FsdLocation? source = fsd?.source;
    if (fsd == null || source == null || source.slice == null) return;
    if (source.rest.split('/').first != config.directoryName) return;
    final _Visitor visitor = _Visitor(this, config, fsd.packageName);
    registry
      ..addImportDirective(this, visitor)
      ..addExportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.config, this.ownPackage);

  final AnalysisRule rule;
  final DomainPurityConfig config;
  final String ownPackage;

  @override
  void visitImportDirective(ImportDirective node) => _check(node);

  @override
  void visitExportDirective(ExportDirective node) => _check(node);

  void _check(NamespaceDirective node) {
    final String? uri = node.uri.stringValue;
    if (uri == null) return;
    if (uri.startsWith('dart:')) {
      if (uri == 'dart:ui') rule.reportAtNode(node.uri, arguments: [uri]);
      return;
    }
    if (!uri.startsWith('package:')) return;
    final String package = uri.substring('package:'.length).split('/').first;
    if (package == ownPackage || config.allowedPackages.contains(package)) {
      return;
    }
    rule.reportAtNode(node.uri, arguments: [uri]);
  }
}
