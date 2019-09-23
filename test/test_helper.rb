# frozen_string_literal: true
require "bundler/setup"
require "minitest/autorun"
require "mocha/minitest"
require "byebug"
require "spy"
require "licensed"
require "English"
require "test_helpers/test_command"
require "test_helpers/test_shell"
require "test_helpers/test_reporter"
require "test_helpers/test_source"

def each_source(&block)
  Licensed::Sources::Source.sources.each do |source_class|
    # don't run tests meant for actual dependency enumerators on the test source
    next if source_class == TestSource

    # if a specific source type is set via ENV, skip other source types
    next if ENV["SOURCE"] && source_class.type != ENV["SOURCE"].downcase

    block.call(source_class)
  end
end
