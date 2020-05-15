#!/bin/bash
set -e

if [ -z "$(which dotnet)" ]; then
  echo "A local dotnet installation is required for dotnet/nuget development." >&2
  exit 127
fi

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/nuget

if [ "$1" == "-f" ]; then
  dotnet clean
fi

dotnet restore
