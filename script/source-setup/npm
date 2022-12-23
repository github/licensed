#!/bin/bash
set -e

if [ -z "$(which npm)" ]; then
  echo "A local npm installation is required for npm development." >&2
  exit 127
fi

# setup test fixtures
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd $BASE_PATH/test/fixtures/npm

if [ "$1" == "-f" ]; then
  git clean -ffX .
fi

NPM_MAJOR_VERSION="$(npm -v | cut -d'.' -f1)"
if [ "$NPM_MAJOR_VERSION" -ge "7" ]; then
  # do no install peerDependencies in npm 7
  npm install --legacy-peer-deps
else
  npm install
fi
