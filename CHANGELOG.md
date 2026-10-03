## 0.3.0

- **Breaking:** `fsd_layer_imports`, `fsd_no_cross_slice` and `fsd_public_api`
  now check relative imports/exports too. Before, only
  `package:<own package>/` URIs were checked, so a violation written as a
  relative URI (e.g. `'../../features/x/x.dart'`) wasn't reported. Projects
  that use relative imports may see new diagnostics.
- The `fsd_public_api` quick fix keeps the URI style: a relative import is
  rewritten to a relative URI of the barrel file.

## 0.2.0

- **Breaking:** Removed the rules unrelated to Feature-Sliced Design:
  `banned_imports`, `presentational_purity`, `provider_declaration_location`,
  `no_direct_datetime_now` and `no_direct_debug_print`, along with their
  `feature_sliced_lints.yaml` sections. The package now only covers FSD:
  `fsd_layer_imports`, `fsd_no_cross_slice`, `fsd_public_api` and
  `domain_purity`.

## 0.1.0

- Initial release: `fsd_layer_imports`, `fsd_no_cross_slice`, `fsd_public_api`,
  `domain_purity`, `banned_imports`, `presentational_purity`,
  `provider_declaration_location`, `no_direct_datetime_now` and
  `no_direct_debug_print`, configured through `feature_sliced_lints.yaml`.
- Quick fix for `fsd_public_api`: import through the barrel file.
