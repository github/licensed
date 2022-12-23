#!/bin/bash
set -e

if [ -z "$(which yarn)" ]; then
  echo "A local yarn installation is required for yarn development." >&2
  exit 127
fi

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd $BASE_PATH/test/fixtures/yarn/berry

if [ "$1" == "-f" ]; then
  git clean -ffX .
fi

yarn install
