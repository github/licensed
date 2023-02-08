#!/bin/bash
set -e

if [ -z "$(which pnpm)" ]; then
  echo "A local pnpm installation is required for pnpm development." >&2
  exit 127
fi

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/pnpm

if [ "$1" == "-f" ]; then
  git clean -ffX .
fi

pnpm install --shamefully-hoist
