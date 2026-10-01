import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:yaml/yaml.dart';

/// The config file name. Placed at the root of the analyzed package (next to
/// `pubspec.yaml`).
///
/// The `diagnostics` section of `analysis_options.yaml` only carries
/// enable/disable and severity per rule, so project-specific values
/// (layer names, allowed packages, ...) are passed through this file.
const String lintConfigFileName = 'feature_sliced_lints.yaml';

/// How a slice exposes its public API.
enum BarrelStyle {
  /// `<layer>/<slice>/<slice>.dart` (the Dart package convention).
  sliceName,

  /// `<layer>/<slice>/index.dart` (the FSD convention from the JS world).
  indexFile,
}

/// The `fsd` section: where the layers live and what they are called.
class FsdConfig {
  FsdConfig({
    this.root = 'lib',
    this.layers = defaultLayers,
    Set<String>? slicedLayers,
    this.barrel = BarrelStyle.sliceName,
    this.crossSliceHints = const {},
  }) : slicedLayers =
           slicedLayers ??
           {
             if (layers.length > 2)
               ...layers.sublist(1, layers.length - 1)
             else
               ...layers,
           };

  /// The FSD layers from top to bottom (FSD v2 without the deprecated
  /// `processes`).
  static const List<String> defaultLayers = [
    'app',
    'pages',
    'widgets',
    'features',
    'entities',
    'shared',
  ];

  /// The directory that holds the layers, relative to the package root.
  /// Always `lib` or a directory under it (e.g. `lib/src`).
  final String root;

  /// Layers from top to bottom. Imports may only point downward.
  final List<String> layers;

  /// Layers that are divided into slices. Defaults to every layer except the
  /// first and the last (`app` and `shared` have no slices in FSD).
  final Set<String> slicedLayers;

  final BarrelStyle barrel;

  /// Per-layer replacement for the correction message of
  /// `fsd_no_cross_slice` (e.g. "Navigate through the router instead.").
  final Map<String, String> crossSliceHints;

  /// [root] below `lib/`, as path segments (empty when [root] is `lib`).
  List<String> get rootSegmentsUnderLib =>
      root.split('/').where((String s) => s.isNotEmpty).skip(1).toList();

  /// The barrel file name of [slice].
  String barrelFileOf(String slice) => switch (barrel) {
    BarrelStyle.sliceName => '$slice.dart',
    BarrelStyle.indexFile => 'index.dart',
  };
}

/// One entry of `banned_imports`: bans imports/exports starting with
/// [uriPrefix].
class BannedImport {
  const BannedImport({required this.uriPrefix, required this.reason});

  final String uriPrefix;
  final String reason;
}

/// The `domain_purity` section.
class DomainPurityConfig {
  const DomainPurityConfig({
    required this.directoryName,
    required this.allowedPackages,
  });

  /// The directory treated as the domain layer
  /// (`<root>/<layer>/<slice>/<this>/`).
  final String directoryName;

  /// Packages other than the own package that may be imported. `dart:`
  /// libraries are always allowed, except `dart:ui`.
  final Set<String> allowedPackages;
}

/// The `presentational_purity` section.
class PresentationalPurityConfig {
  const PresentationalPurityConfig({
    this.fileSuffix = '_view.dart',
    this.forbiddenPackages = const {},
  });

  /// Files ending with this are presentational.
  final String fileSuffix;

  /// Packages presentational files must not import. Nothing is checked while
  /// this is empty.
  final Set<String> forbiddenPackages;
}

/// The `provider_declaration_location` section.
class ProviderDeclarationLocationConfig {
  const ProviderDeclarationLocationConfig({
    this.fileSuffix = '_providers.dart',
  });

  /// The only files where Riverpod providers may be declared.
  final String fileSuffix;
}

/// The contents of [lintConfigFileName]. A missing file means the defaults.
class LintConfig {
  LintConfig({
    FsdConfig? fsd,
    this.bannedImports = const [],
    this.domainPurity,
    this.presentationalPurity = const PresentationalPurityConfig(),
    this.providerDeclarationLocation =
        const ProviderDeclarationLocationConfig(),
  }) : fsd = fsd ?? FsdConfig();

  final FsdConfig fsd;
  final List<BannedImport> bannedImports;

  /// `null` turns `domain_purity` off.
  final DomainPurityConfig? domainPurity;
  final PresentationalPurityConfig presentationalPurity;
  final ProviderDeclarationLocationConfig providerDeclarationLocation;

  static final LintConfig defaults = LintConfig();

  /// Reads the config of the package that the analyzed file belongs to.
  ///
  /// Rules run once per file, so the parsed result is cached while the
  /// content stays the same. The content (not the modification time) is the
  /// key because in-memory file systems (tests) may keep the same stamp after
  /// a rewrite. The file is small and cheap to read.
  ///
  /// A malformed file throws [FormatException] only the first time for the
  /// same content (the analysis server reports it as an unexpected error and
  /// `dart analyze` exits non-zero). Throwing on every file would repeat the
  /// same stack trace once per file, so later calls fall back to the defaults.
  static LintConfig of(RuleContext context) =>
      forPackageRoot(context.package?.root);

  /// Reads the config placed at [root] (the folder holding `pubspec.yaml`).
  static LintConfig forPackageRoot(Folder? root) {
    if (root == null) return defaults;
    final File file = root.getFile(lintConfigFileName);
    if (!file.exists) return defaults;
    final String content = file.readAsStringSync();
    final _Cached? cached = _cache[file.path];
    if (cached != null && cached.content == content) return cached.config;
    try {
      final LintConfig config = parse(content);
      _cache[file.path] = _Cached(content, config);
      return config;
    } on FormatException {
      _cache[file.path] = _Cached(content, defaults);
      rethrow;
    }
  }

  static final Map<String, _Cached> _cache = {};

  /// Parses a YAML string. Malformed entries throw [FormatException] so that
  /// a typo never silently turns into "nothing is checked".
  static LintConfig parse(String yaml) {
    final Object? root = loadYaml(yaml);
    if (root == null) return defaults;
    if (root is! YamlMap) {
      throw const FormatException('$lintConfigFileName must be a map.');
    }
    return LintConfig(
      fsd: _parseFsd(root['fsd']),
      bannedImports: _parseBannedImports(root['banned_imports']),
      domainPurity: _parseDomainPurity(root['domain_purity']),
      presentationalPurity: _parsePresentationalPurity(
        root['presentational_purity'],
      ),
      providerDeclarationLocation: _parseProviderDeclarationLocation(
        root['provider_declaration_location'],
      ),
    );
  }

  static FsdConfig _parseFsd(Object? node) {
    if (node == null) return FsdConfig();
    final YamlMap map = _map(node, 'fsd');
    final String root = _string(map['root'], 'fsd.root') ?? 'lib';
    if (root != 'lib' && !root.startsWith('lib/')) {
      throw FormatException('fsd.root must be lib or under lib: $root');
    }
    final List<String> layers =
        _strings(map['layers'], 'fsd.layers') ?? FsdConfig.defaultLayers;
    if (layers.isEmpty || layers.toSet().length != layers.length) {
      throw const FormatException(
        'fsd.layers must be a non-empty list of unique names.',
      );
    }
    final List<String>? sliced = _strings(
      map['sliced_layers'],
      'fsd.sliced_layers',
    );
    if (sliced != null && !sliced.every(layers.contains)) {
      throw const FormatException(
        'fsd.sliced_layers must be a subset of fsd.layers.',
      );
    }
    final String barrel = _string(map['barrel'], 'fsd.barrel') ?? 'slice';
    final Map<String, String> hints = {};
    final Object? hintsNode = map['cross_slice_hints'];
    if (hintsNode != null) {
      for (final MapEntry<Object?, Object?> e in _map(
        hintsNode,
        'fsd.cross_slice_hints',
      ).entries) {
        if (e.key is! String || e.value is! String) {
          throw const FormatException(
            'fsd.cross_slice_hints maps layer names to strings.',
          );
        }
        hints[e.key! as String] = e.value! as String;
      }
    }
    return FsdConfig(
      root: root,
      layers: layers,
      slicedLayers: sliced?.toSet(),
      barrel: switch (barrel) {
        'slice' => BarrelStyle.sliceName,
        'index' => BarrelStyle.indexFile,
        _ => throw FormatException(
          'fsd.barrel must be slice or index: $barrel',
        ),
      },
      crossSliceHints: hints,
    );
  }

  static List<BannedImport> _parseBannedImports(Object? node) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw const FormatException('banned_imports must be a list.');
    }
    return [
      for (final Object? entry in node)
        if (entry case {'uri': final String uri, 'reason': final String reason})
          BannedImport(uriPrefix: uri, reason: reason)
        else
          throw FormatException(
            'Each banned_imports entry needs uri and reason: $entry',
          ),
    ];
  }

  static DomainPurityConfig? _parseDomainPurity(Object? node) {
    if (node == null) return null;
    final YamlMap map = _map(node, 'domain_purity');
    return DomainPurityConfig(
      directoryName:
          _string(map['directory'], 'domain_purity.directory') ?? 'domain',
      allowedPackages: {
        ...?_strings(map['allowed_packages'], 'domain_purity.allowed_packages'),
      },
    );
  }

  static PresentationalPurityConfig _parsePresentationalPurity(Object? node) {
    if (node == null) return const PresentationalPurityConfig();
    final YamlMap map = _map(node, 'presentational_purity');
    return PresentationalPurityConfig(
      fileSuffix:
          _string(map['file_suffix'], 'presentational_purity.file_suffix') ??
          '_view.dart',
      forbiddenPackages: {
        ...?_strings(
          map['forbidden_packages'],
          'presentational_purity.forbidden_packages',
        ),
      },
    );
  }

  static ProviderDeclarationLocationConfig _parseProviderDeclarationLocation(
    Object? node,
  ) {
    if (node == null) return const ProviderDeclarationLocationConfig();
    final YamlMap map = _map(node, 'provider_declaration_location');
    return ProviderDeclarationLocationConfig(
      fileSuffix:
          _string(
            map['file_suffix'],
            'provider_declaration_location.file_suffix',
          ) ??
          '_providers.dart',
    );
  }

  static YamlMap _map(Object? node, String key) {
    if (node is! YamlMap) throw FormatException('$key must be a map.');
    return node;
  }

  static String? _string(Object? node, String key) {
    if (node == null) return null;
    if (node is! String) throw FormatException('$key must be a string.');
    return node;
  }

  static List<String>? _strings(Object? node, String key) {
    if (node == null) return null;
    if (node is! YamlList || !node.every((Object? e) => e is String)) {
      throw FormatException('$key must be a list of strings.');
    }
    return node.cast<String>().toList();
  }
}

/// The nearest folder above [file] that holds a `pubspec.yaml`.
Folder? packageRootOf(File file) {
  for (Folder folder = file.parent; ; folder = folder.parent) {
    if (folder.getFile('pubspec.yaml').exists) return folder;
    if (folder.isRoot) return null;
  }
}

class _Cached {
  const _Cached(this.content, this.config);

  final String content;
  final LintConfig config;
}
