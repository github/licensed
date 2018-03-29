#!/bin/bash

set -e

if [ "$#" -gt "0" ] ; then
  if [ -f "$1" ]; then
    # argument was a file, run it's tests only
    bundle exec rake test TEST="$1"
  else
    # argument was not a file, execute it as a test suite identifier
    bundle exec rake test:"$1"
  fi
else
  # no arguments, run all tests
  bundle exec rake test
fi
