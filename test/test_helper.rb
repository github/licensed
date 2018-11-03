# frozen_string_literal: true
require "bundler/setup"
require "minitest/autorun"
require "licensed"
require "English"

class TestSource < Licensed::Sources::Source
  def initialize(config, metadata = {})
    super config
    @metadata = metadata
  end

  def self.type
    "test"
  end

  def enabled?
    true
  end

  def enumerate_dependencies
    [
      Licensed::Dependency.new(Dir.pwd, {
        "type"     => TestSource.type,
        "name"     => "dependency",
        "version"  => "1.0",
        "dir"      => Dir.pwd
      }.merge(@metadata))
    ]
  end
end

def each_source(&block)
  Licensed::Sources::Source.sources.each do |source_class|
    # don't run tests meant for actual dependency enumerators on the test source
    next if source_class == TestSource

    # if a specific source type is set via ENV, skip other source types
    next if ENV["SOURCE"] && source_class.type != ENV["SOURCE"].downcase

    block.call(source_class)
  end
end
