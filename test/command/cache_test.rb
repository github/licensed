# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::Cache do
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new(config) }
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

  each_source do |source_class|
    describe "with #{source_class.type}" do
      let(:source_type) { source_class.type }
      let(:config_file) { File.join(fixtures, "command/#{source_type}.yml") }
      let(:config) { Licensed::Configuration.load_from(config_file) }
      let(:source) { source_class.new(config) }
      let(:expected_dependency) { config["expected_dependency"] }

      it "extracts license info" do
        config.apps.each do |app|
          enabled = Dir.chdir(app.source_path) { source.enabled? }
          next unless enabled

          generator.run

          path = app.cache_path.join("#{source_type}/#{expected_dependency}.#{Licensed::DependencyRecord::EXTENSION}")
          assert path.exist?
          license = Licensed::DependencyRecord.read(path)
          assert_equal expected_dependency, license["name"]
          assert license["license"]
        end
      end
    end
  end

  it "cleans up old dependencies" do
    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/old_dep.#{Licensed::DependencyRecord::EXTENSION}"), ""
    generator.run
    refute config.cache_path.join("test/old_dep.#{Licensed::DependencyRecord::EXTENSION}").exist?
  end

  it "cleans up ignored dependencies" do
    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
    config.ignore "type" => "test", "name" => "dependency"
    generator.run
    refute config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
  end

  it "uses cached license if license text does not change" do
    generator.run

    path = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    license = Licensed::DependencyRecord.read(path)
    license["license"] = "test"
    license["version"] = "0.0"
    license.save(path)

    generator.run

    license = Licensed::DependencyRecord.read(path)
    assert_equal "test", license["license"]
    refute_equal "0.0", license["version"]
  end

  it "does not reuse nil license version" do
    generator.run

    path = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    license = Licensed::DependencyRecord.read(path)
    license["license"] = "test"
    license.save(path)

    test_dependency = Licensed::Dependency.new(
      name: "dependency",
      version: "1.0",
      path: Dir.pwd,
      metadata: {
        "type"     => TestSource.type
      }
    )
    source.stub(:enumerate_dependencies, [test_dependency]) do
      generator.run
    end

    license = Licensed::DependencyRecord.read(path)
    assert_equal "test", license["license"]
    assert_equal "1.0", license["version"]
  end

  it "does not reuse empty license version" do
    generator.run

    path = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    license = Licensed::DependencyRecord.read(path)
    license["license"] = "test"
    license["version"] = ""
    license.save(path)

    test_dependency = Licensed::Dependency.new(
      name: "dependency",
      version: "1.0",
      path: Dir.pwd,
      metadata: {
        "type"     => TestSource.type
      }
    )
    source.stub(:enumerate_dependencies, [test_dependency]) do
      generator.run
    end

    license = Licensed::DependencyRecord.read(path)
    assert_equal "test", license["license"]
    assert_equal "1.0", license["version"]
  end

  it "does not include ignored dependencies in dependency counts" do
    config.ui.level = "info"
    out, _ = capture_io { generator.run }
    count = out.match(/dependencies: (\d+)/)[1].to_i

    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
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
      assert config["apps"][0].cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
      assert config["apps"][1].cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end

  describe "with app.source_path" do
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      generator.run
      assert_equal fixtures, source.dependencies.first.record["dir"]
    end
  end

  describe "with explicit dependency file path" do
    let(:source) { TestSource.new(config, "dependency/path", "name" => "dependency") }

    it "caches metadata at the given file path" do
      generator.run
      assert config.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end
end
