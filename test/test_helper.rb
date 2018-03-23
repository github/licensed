# frozen_string_literal: true
require "bundler/setup"
require "minitest/autorun"
require "licensed"
require "English"

# Make sure this doesn't get recorded in VCR responses
ENV["GITHUB_TOKEN"] = nil

require "vcr"
VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("../fixtures/vcr", __FILE__)
  config.hook_into :webmock
end

Minitest::Spec.class_eval do
  before do
    Licensed.use_github = false
  end
end

class TestSource
  attr_accessor :dependencies_hook

  def initialize
    @dependencies_hook = nil
  end

  def type
    "test"
  end

  def enabled?
    true
  end

  def dependencies
    @dependencies_hook.call if @dependencies_hook.respond_to?(:call)
    @dependencies ||= [
      Licensed::Dependency.new(Dir.pwd, {
        "type"     => type,
        "name"     => "dependency",
        "version"  => "1.0"
      })
    ]
  end
end
