#!/bin/bash
set -e

if [ -z "$(which cargo)" ]; then
  echo "A local cargo installation is required for rustc development." >&2
  exit 127
fi

cargo --version

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/cargo

if [ "$1" == "-f" ]; then
  cargo clean
fi

cargo build
