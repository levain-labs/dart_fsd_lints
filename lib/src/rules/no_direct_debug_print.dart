import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Disallows `print`/`debugPrint` (including tear-offs) so that output goes
/// through a logger. Exclude the logger's console sink explicitly with
/// `// ignore_for_file: fsd_lints/no_direct_debug_print`.
class NoDirectDebugPrint extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_direct_debug_print',
    "Don't call '{0}' directly.",
    correctionMessage: 'Log through a logger instead.',
  );

  NoDirectDebugPrint()
    : super(
        name: 'no_direct_debug_print',
        description: 'Use a logger instead of print/debugPrint.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!context.isInLibDir) return;
    registry.addSimpleIdentifier(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Declarations and `import ... show debugPrint` are not calls.
    if (node.inDeclarationContext() || node.parent is Combinator) return;
    final Element? element = node.element;
    if (element == null) return;
    final String? name = switch (element) {
      GetterElement(:final variable) => variable.name,
      _ => element.name,
    };
    final Uri? library = element.library?.uri;
    if (library == null) return;
    final bool isPrint = name == 'print' && library.toString() == 'dart:core';
    final bool isDebugPrint =
        name == 'debugPrint' &&
        library.toString().startsWith('package:flutter/');
    if (isPrint || isDebugPrint) {
      rule.reportAtNode(node, arguments: [name!]);
    }
  }
}
