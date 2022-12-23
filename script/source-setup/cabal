#!/bin/bash
set -e

if [ -z "$(which cabal)" ]; then
  echo "A local cabal installation is required for cabal development." >&2
  exit 127
fi

cabal --version

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/cabal

if [ "$1" == "-f" ]; then
  git clean -ffX .
fi

(cabal new-update && cabal new-build) || (cabal update && cabal install)
