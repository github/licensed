#!/bin/sh

set -e

bundle exec rake test
bundle exec rubocop -S -D
gem build licensed.gemspec
