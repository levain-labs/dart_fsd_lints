import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';

/// Restricts top-level Riverpod provider declarations to `*_providers.dart`
/// (configurable with `provider_declaration_location.file_suffix`).
class ProviderDeclarationLocation extends AnalysisRule {
  static const LintCode code = LintCode(
    'provider_declaration_location',
    "The provider '{0}' must be declared in a '*{1}' file.",
    correctionMessage:
        "Move the declaration to the slice's '*{1}' file and keep the logic "
        'here as a function.',
  );

  ProviderDeclarationLocation()
    : super(
        name: 'provider_declaration_location',
        description: 'Declare Riverpod providers only in *_providers.dart.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    final String suffix = LintConfig.of(
      context,
    ).providerDeclarationLocation.fileSuffix;
    registry.addTopLevelVariableDeclaration(
      this,
      _Visitor(this, context, suffix),
    );
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context, this.suffix);

  final AnalysisRule rule;
  final RuleContext context;
  final String suffix;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final String? fileName = context.currentUnit?.file.shortName;
    if (fileName == null || fileName.endsWith(suffix)) return;
    for (final VariableDeclaration variable in node.variables.variables) {
      final DartType? type = variable.declaredFragment?.element.type;
      if (type is InterfaceType && _isRiverpodProvider(type)) {
        rule.reportAtToken(
          variable.name,
          arguments: [variable.name.lexeme, suffix],
        );
      }
    }
  }

  /// Whether it implements `ProviderOrFamily`, the common base of every
  /// Riverpod 3 provider (families included).
  static bool _isRiverpodProvider(InterfaceType type) {
    return [type, ...type.allSupertypes].any(
      (InterfaceType t) =>
          t.element.name == 'ProviderOrFamily' &&
          t.element.library.uri.toString().startsWith('package:riverpod/'),
    );
  }
}
