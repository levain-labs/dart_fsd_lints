import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Disallows calling `DateTime.now()` directly so that time is injected
/// through a clock. Exclude the production clock implementation explicitly
/// with `// ignore: feature_sliced_lints/no_direct_datetime_now`.
class NoDirectDatetimeNow extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_direct_datetime_now',
    "Don't call DateTime.now() directly.",
    correctionMessage: 'Use now() of an injected clock.',
  );

  NoDirectDatetimeNow()
    : super(
        name: 'no_direct_datetime_now',
        description: 'Inject a clock instead of calling DateTime.now().',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final ConstructorElement? constructor = node.constructorName.element;
    if (constructor == null || constructor.name != 'now') return;
    final InterfaceElement owner = constructor.enclosingElement;
    if (owner.name == 'DateTime' && owner.library.isDartCore) {
      rule.reportAtNode(node);
    }
  }
}
