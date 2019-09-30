#!/bin/bash
set -e

if [ -z "$(which mix)" ]; then
  echo "A local mix installation is required for elixir development." >&2
  exit 127
fi

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/mix

if [ "$1" == "-f" ]; then
  echo "removing old fixture setup..."
  mix deps.clean --all || true
  mix clean || true
fi

mix deps.get
