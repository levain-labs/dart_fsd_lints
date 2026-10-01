# feature_sliced_lints

An analyzer plugin that enforces [Feature-Sliced Design](https://feature-sliced.design/)
in Dart and Flutter projects, plus a few conventions that usually come with it.

It is built on the official analyzer plugin system (`analysis_server_plugin`),
so diagnostics show up in the IDE and in `dart analyze` without extra tooling.

## Rules

| Rule | What it checks |
|---|---|
| `fsd_layer_imports` | Layers only import downward (`app → pages → widgets → features → entities → shared`). |
| `fsd_no_cross_slice` | Slices on the same layer don't import each other, except through `@x` entry points (`<layer>/<other>/@x/<me>.dart`). |
| `fsd_public_api` | Outside a slice, import it only through its barrel file (`<slice>/<slice>.dart` or `<slice>/index.dart`). Has a quick fix that rewrites the URI to the barrel file. |
| `domain_purity` | The domain directory of each slice stays pure Dart: only its own package, `dart:` (except `dart:ui`) and allowed packages. |
| `banned_imports` | Imports/exports starting with a configured URI prefix are reported with your reason. |
| `presentational_purity` | Presentational files (`*_view.dart`) don't import configured packages (state management, persistence, analytics, ...). |
| `provider_declaration_location` | Top-level Riverpod 3 providers are declared only in `*_providers.dart`. |
| `no_direct_datetime_now` | `DateTime.now()` isn't called directly (inject a clock instead). |
| `no_direct_debug_print` | `print` / `debugPrint` aren't called directly (use a logger instead). |

## Setup

Add the plugin to `analysis_options.yaml` and enable the rules you want.
Plugin rules are disabled by default.

```yaml
plugins:
  feature_sliced_lints:
    version: ^0.1.0
    diagnostics:
      fsd_layer_imports: true
      fsd_no_cross_slice: true
      fsd_public_api: true
      domain_purity: true
      banned_imports: true
      presentational_purity: true
      provider_declaration_location: true
      no_direct_datetime_now: true
      no_direct_debug_print: true
```

Restart the Dart Analysis Server in your IDE after changing the `plugins`
section.

Only `version:` (pub.dev) and `path:` work as plugin sources. With `git:`, the
analysis server silently skips the plugin and reports no issues. Whenever you
change how the plugin is referenced, add a deliberate violation once and check
that it is reported.

Use `dart analyze` (not `flutter analyze`) on CI: at the time of writing,
`flutter analyze` doesn't report plugin diagnostics. Plugin lints are infos,
so add `--fatal-infos` to fail the build on them.

To suppress a diagnostic, prefix the rule with the plugin name:

```dart
// ignore: feature_sliced_lints/no_direct_datetime_now
```

## Configuration

Put `feature_sliced_lints.yaml` next to `pubspec.yaml`. Everything is optional; a missing
file means the defaults below. A malformed file fails the analysis instead of
silently checking nothing.

```yaml
fsd:
  # The directory that holds the layers: lib, or a directory under it.
  root: lib
  # Layers from top to bottom.
  layers: [app, pages, widgets, features, entities, shared]
  # Layers divided into slices. Defaults to all layers but the first and last.
  sliced_layers: [pages, widgets, features, entities]
  # slice: <slice>/<slice>.dart, index: <slice>/index.dart
  barrel: slice
  # Replaces the fsd_no_cross_slice correction for a layer.
  cross_slice_hints:
    pages: Navigate through the router instead.

# Off unless present.
domain_purity:
  directory: domain # <root>/<layer>/<slice>/domain/
  allowed_packages: [meta, collection]

banned_imports:
  - uri: package:mockito/
    reason: Use fakes instead of mocks.

presentational_purity:
  file_suffix: _view.dart
  forbidden_packages: [flutter_riverpod, cloud_firestore] # nothing is checked while empty

provider_declaration_location:
  file_suffix: _providers.dart
```

## Quick fixes

| Rule | Fix |
|---|---|
| `fsd_public_api` | Rewrites the import/export URI to the slice's barrel file. Offered one location at a time in the IDE; plugin fixes can't be applied in bulk with `dart fix`. If the barrel doesn't export the symbol yet, export it there. |

## Compatibility

The analyzer moves in lockstep with the Dart SDK. This version requires Dart
3.12 or later (Flutter that bundles it).
