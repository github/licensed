# frozen_string_literal: true

class TestSource < Licensed::Sources::Source
  def initialize(config, name = "dependency", metadata = {})
    super config
    @dependency_config = {
      name: name,
      version: "1.0",
      path: Dir.pwd,
      metadata: {
        "type" => TestSource.type,
        "dir" => Dir.pwd
      }.merge(metadata)
    }.merge(config["test"] || {})
  end

  def self.type
    "test"
  end

  def enabled?
    true
  end

  def enumerate_dependencies
    [Licensed::Dependency.new(**@dependency_config)]
  end
end
