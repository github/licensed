#!/bin/bash
set -e

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$BASE_PATH/test/fixtures/cocoapods"

if [ "$1" == "-f" ]; then
  git clean -ffX .
fi

# install cocoapods and cocoapods-dependencies-list plugin
bundle config set path 'vendor/gems'
bundle install

OPTIONS=()
if [ "$1" == "-f" ]; then
  OPTIONS+="--clean-install"
fi

bundle exec pod install "${OPTIONS[@]}"
