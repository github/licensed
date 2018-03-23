# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::Cache do
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new }
  let(:generator) { Licensed::Command::Cache.new(config) }

  before do
    config.ui.level = "silent"
    FileUtils.rm_rf config.cache_path
    config.apps.each do |app|
      app.sources.clear
      app.sources << source
    end
  end

  it "extracts license info for each ruby dep" do
    generator.run
    assert config.cache_path.join("test/dependency.txt").exist?
    license = Licensed::License.read(config.cache_path.join("test/dependency.txt"))
    assert_equal "dependency", license["name"]
    assert_equal "mit", license["license"]
  end

  it "cleans up old dependencies" do
    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/old_dep.txt"), ""
    generator.run
    refute config.cache_path.join("test/old_dep.txt").exist?
  end

  it "cleans up ignored dependencies" do
    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/dependency.txt"), ""
    config.ignore "type" => "test", "name" => "dependency"
    generator.run
    refute config.cache_path.join("test/dependency.txt").exist?
  end

  it "does not include ignored dependencies in dependency counts" do
    config.ui.level = "info"
    out, _ = capture_io { generator.run }
    count = out.match(/dependencies: (\d+)/)[1].to_i

    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/dependency.txt"), ""
    config.ignore "type" => "test", "name" => "dependency"

    out, _ = capture_io { generator.run }
    ignored_count = out.match(/dependencies: (\d+)/)[1].to_i
    assert_equal count - 1, ignored_count
  end

  describe "with multiple apps" do
    let(:apps) do
      [
        {
          "name" => "app1",
          "cache_path" => "vendor/licenses/app1",
          "source_path" => Dir.pwd
        },
        {
          "name" => "app2",
          "cache_path" => "vendor/licenses/app2",
          "source_path" => Dir.pwd
        }
      ]
    end
    let(:config) { Licensed::Configuration.new("apps" => apps) }

    it "caches metadata for all apps" do
      generator.run
      assert config["apps"][0].cache_path.join("test/dependency.txt").exist?
      assert config["apps"][1].cache_path.join("test/dependency.txt").exist?
    end
  end

  describe "with app.source_path" do
    let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      source.dependencies_hook = -> { assert_equal fixtures, Dir.pwd }
      generator.run
    end
  end
end
