#!/bin/bash
set -e

if [ -z "$(which go)" ]; then
  echo "A local Go installation is required for go development." >&2
  exit 127
fi

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export GOPATH="$BASE_PATH/test/fixtures/go"
cd "$BASE_PATH/test/fixtures/go"

if [ "$1" == "-f" ]; then
  git clean -ffX .
  go clean -modcache
fi

cd src/test
go mod download
