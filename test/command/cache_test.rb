# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::Cache do
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new }
  let(:generator) { Licensed::Command::Cache.new(config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
    config.ui.level = "silent"
    config.apps.each do |app|
      app.sources.clear
      app.sources << source
    end
  end

  after do
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end
  end

  each_source do |source_type|
    describe "with #{source_type}" do
      let(:yaml) { YAML.load_file(File.join(fixtures, "command/#{source_type.to_s.downcase}.yml")) }
      let(:expected_dependency) { yaml["expected_dependency"] }

      let(:config) { Licensed::Configuration.new(yaml["config"]) }
      let(:source) { Licensed::Source.const_get(source_type).new(config) }

      it "extracts license info" do
        generator.run

        path = config.cache_path.join("#{source.type}/#{expected_dependency}.txt")
        assert path.exist?
        license = Licensed::License.read(path)
        assert_equal expected_dependency, license["name"]
        assert license["license"]
      end
    end
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

  it "uses cached license if license text does not change" do
    generator.run

    path = config.cache_path.join("test/dependency.txt")
    license = Licensed::License.read(path)
    license["license"] = "test"
    license["version"] = "0.0"
    license.save(path)

    generator.run

    license = Licensed::License.read(path)
    assert_equal "test", license["license"]
    refute_equal "0.0", license["version"]
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
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      source.dependencies_hook = -> { assert_equal fixtures, Dir.pwd }
      generator.run
    end
  end
end
