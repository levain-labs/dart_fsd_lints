#!/usr/bin/env bash
# mise.toml の Dart のバージョンを出力する。CI と公開で同じ SDK を使うため。
# pubspec.yaml の SDK 下限(^x.y.z)とずれていたら失敗する。
set -euo pipefail

version=$(sed -n 's/^dart *= *"\([^"]*\)".*/\1/p' mise.toml)
if [ -z "$version" ]; then
  echo "::error file=mise.toml::dart のバージョンが見つからない" >&2
  exit 1
fi
lower=$(sed -n 's/^  sdk: *\^\(.*\)$/\1/p' pubspec.yaml)
if [ "$version" != "$lower" ]; then
  echo "::error file=pubspec.yaml::mise.toml の Dart ($version) と pubspec.yaml の SDK 下限 ($lower) がずれている" >&2
  exit 1
fi
echo "$version"
