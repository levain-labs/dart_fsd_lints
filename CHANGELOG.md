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
