# frozen_string_literal: true

class TestSource < Licensed::Sources::Source
  def initialize(config, name = "dependency", metadata = {})
    super config
    @metadata = metadata
    @name = name
  end

  def self.type
    "test"
  end

  def enabled?
    true
  end

  def enumerate_dependencies
    [
      Licensed::Dependency.new(
        name: @name,
        version: "1.0",
        path: Dir.pwd,
        metadata: {
          "type"     => TestSource.type,
          "dir"      => Dir.pwd
        }.merge(@metadata)
      )
    ]
  end
end
