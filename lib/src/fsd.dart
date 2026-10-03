import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:feature_sliced_lints/src/lint_config.dart';

/// A path under the FSD root, split into layer, slice and the rest.
class FsdLocation {
  const FsdLocation({
    required this.config,
    required this.layer,
    this.slice,
    required this.rest,
  });

  /// Splits [libRelativePath] (e.g. `pages/settings/settings_screen.dart`,
  /// relative to `lib/`). Returns `null` outside the layers (e.g.
  /// `main.dart`, or anything outside [FsdConfig.root]).
  static FsdLocation? parse(FsdConfig config, String libRelativePath) {
    final List<String> root = config.rootSegmentsUnderLib;
    final List<String> all = libRelativePath.split('/');
    if (all.length <= root.length) return null;
    for (int i = 0; i < root.length; i++) {
      if (all[i] != root[i]) return null;
    }
    final List<String> segments = all.sublist(root.length);
    if (segments.length < 2 || !config.layers.contains(segments.first)) {
      return null;
    }
    final String layer = segments.first;
    if (!config.slicedLayers.contains(layer) || segments.length < 3) {
      return FsdLocation(
        config: config,
        layer: layer,
        rest: segments.skip(1).join('/'),
      );
    }
    return FsdLocation(
      config: config,
      layer: layer,
      slice: segments[1],
      rest: segments.skip(2).join('/'),
    );
  }

  final FsdConfig config;
  final String layer;
  final String? slice;

  /// The path inside the slice (inside the layer for unsliced layers).
  final String rest;

  /// The position of the layer. Smaller is higher.
  int get rank => config.layers.indexOf(layer);

  bool isSameSliceAs(FsdLocation other) =>
      layer == other.layer && slice != null && slice == other.slice;

  /// Whether this is the public API (barrel file) of its slice.
  bool get isBarrel {
    final String? s = slice;
    return s != null && rest == config.barrelFileOf(s);
  }

  /// Whether this is an `@x` entry point (FSD v2.1) published for
  /// [consumerSlice].
  bool isCrossImportFor(String consumerSlice) =>
      rest == '@x/$consumerSlice.dart';

  /// The path of the slice's barrel file under `lib/`
  /// (e.g. `entities/user/user.dart`). `null` for unsliced layers.
  String? get barrelPath {
    final String? s = slice;
    return s == null ? null : '$slicePath/${config.barrelFileOf(s)}';
  }

  /// The display path of the slice (e.g. `entities/user`).
  String get slicePath {
    final List<String> root = config.rootSegmentsUnderLib;
    return [...root, layer, ?slice].join('/');
  }
}

/// Resolves the analyzed file and its import/export targets to FSD
/// locations.
class FsdContext {
  FsdContext._(this.sourceUri, this.config, this.source);

  /// Created when the analyzed file is under `lib/` of its own package.
  static FsdContext? of(RuleContext context) {
    final Uri? uri = context.libraryElement?.uri;
    if (uri == null || !uri.isScheme('package') || !context.isInLibDir) {
      return null;
    }
    final FsdConfig config = LintConfig.of(context).fsd;
    return FsdContext._(
      uri,
      config,
      FsdLocation.parse(config, uri.pathSegments.skip(1).join('/')),
    );
  }

  /// The `package:` URI of the analyzed file.
  final Uri sourceUri;
  final FsdConfig config;

  String get packageName => sourceUri.pathSegments.first;

  /// The location of the analyzed file (`null` outside the layers).
  final FsdLocation? source;

  /// The location a directive points to, if it is inside the own package.
  /// Relative URIs are resolved against the analyzed file, so
  /// `'../x/x.dart'` and `'package:<pkg>/.../x/x.dart'` are checked alike.
  FsdLocation? targetOf(NamespaceDirective directive) {
    final String? uri = directive.uri.stringValue;
    if (uri == null) return null;
    final String? libRelativePath = libRelativePathOf(
      packageName,
      resolveDirectiveUri(sourceUri, uri),
    );
    if (libRelativePath == null) return null;
    return FsdLocation.parse(config, libRelativePath);
  }
}

/// Resolves a directive [uri] written in the file at [sourceUri] the way the
/// analyzer does: relative URIs become `package:` URIs (`..` stops at the
/// package's `lib/`), ones with a scheme are returned as they are. `null` when
/// [uri] isn't a valid URI.
Uri? resolveDirectiveUri(Uri sourceUri, String uri) {
  final Uri? parsed = Uri.tryParse(uri);
  return parsed == null ? null : sourceUri.resolveUri(parsed);
}

/// The path under `lib/` that [uri] points to (e.g.
/// `entities/user/user.dart`), if it is a `package:` URI of [packageName].
String? libRelativePathOf(String packageName, Uri? uri) {
  if (uri == null || !uri.isScheme('package')) return null;
  final List<String> segments = uri.pathSegments;
  if (segments.length < 2 || segments.first != packageName) return null;
  return segments.skip(1).join('/');
}
