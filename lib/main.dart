import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:feature_sliced_lints/src/fixes/use_barrel_import.dart';
import 'package:feature_sliced_lints/src/rules/banned_imports.dart';
import 'package:feature_sliced_lints/src/rules/domain_purity.dart';
import 'package:feature_sliced_lints/src/rules/fsd_layer_imports.dart';
import 'package:feature_sliced_lints/src/rules/fsd_no_cross_slice.dart';
import 'package:feature_sliced_lints/src/rules/fsd_public_api.dart';
import 'package:feature_sliced_lints/src/rules/no_direct_datetime_now.dart';
import 'package:feature_sliced_lints/src/rules/no_direct_debug_print.dart';
import 'package:feature_sliced_lints/src/rules/presentational_purity.dart';
import 'package:feature_sliced_lints/src/rules/provider_declaration_location.dart';

/// The entry point the analyzer loads (the `plugin` variable of
/// `lib/main.dart`).
final FeatureSlicedLintsPlugin plugin = FeatureSlicedLintsPlugin();

/// Lint rules for Feature-Sliced Design in Dart/Flutter.
///
/// Every rule is registered with `registerLintRule` (disabled by default) and
/// must be enabled explicitly under `diagnostics` in `analysis_options.yaml`.
class FeatureSlicedLintsPlugin extends Plugin {
  @override
  String get name => 'feature_sliced_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(NoDirectDatetimeNow())
      ..registerLintRule(FsdLayerImports())
      ..registerLintRule(FsdNoCrossSlice())
      ..registerLintRule(FsdPublicApi())
      ..registerLintRule(ProviderDeclarationLocation())
      ..registerLintRule(PresentationalPurity())
      ..registerLintRule(NoDirectDebugPrint())
      ..registerLintRule(DomainPurity())
      ..registerLintRule(BannedImports())
      ..registerFixForRule(FsdPublicApi.code, UseBarrelImport.new);
  }
}
