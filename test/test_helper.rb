# frozen_string_literal: true
require "bundler/setup"
require "minitest/autorun"
require "licensed"
require "English"

class TestSource
  def initialize(metadata = {})
    @metadata = metadata
  end

  def self.type
    "test"
  end

  def enabled?
    true
  end

  def dependencies
    @dependencies ||= [create_dependency]
  end

  def create_dependency
    Licensed::Dependency.new(Dir.pwd, {
      "type"     => TestSource.type,
      "name"     => "dependency",
      "version"  => "1.0",
      "dir"      => Dir.pwd
    }.merge(@metadata))
  end
end

def each_source(&block)
  Licensed::Source.constants.each do |source_type|
    # if a specific source type is set via ENV, skip other source types
    next if ENV["SOURCE"] && source_type.to_s.downcase != ENV["SOURCE"].downcase

    block.call(source_type)
  end
end
