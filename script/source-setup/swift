#!/bin/bash
set -e

if [ -z "$(which swift)" ]; then
  echo "A local swift installation is required for swift development." >&2
  exit 127
fi

swift --version

BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/swift

if [ "$1" == "-f" ]; then
  swift package reset
fi

swift package resolve
