# frozen_string_literal: true

class TestSource < Licensed::Sources::Source
  DEPENDENCY_VERSION = "1.0".freeze
  DEFAULT_DEPENDENCY_NAME = "dependency".freeze

  def initialize(config, name = DEFAULT_DEPENDENCY_NAME, metadata = {})
    super config
    @name = name
    @metadata = metadata
  end

  def self.type
    "test"
  end

  def enabled?
    true
  end

  def enumerate_dependencies
    dependency_config = {
      name: @name,
      version: DEPENDENCY_VERSION,
      path: Dir.pwd,
      metadata: {
        "type" => TestSource.type,
        "dir" => Dir.pwd
      }.merge(@metadata)
    }.merge(config[self.class.type] || {})
    [Licensed::Dependency.new(**dependency_config)]
  end
end
