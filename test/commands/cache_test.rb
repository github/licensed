# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::Cache do
  let(:cache_path) { Dir.mktmpdir }
  let(:reporter) { TestReporter.new }
  let(:config) { Licensed::Configuration.new("cache_path" => cache_path) }
  let(:source) { TestSource.new(config) }
  let(:generator) { Licensed::Commands::Cache.new(config: config, reporter: reporter) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
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
          record = Licensed::DependencyRecord.read(path)
          assert_equal expected_dependency, record["name"]
          assert record["license"]
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

  it "uses cached record if license text does not change" do
    generator.run

    path = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.read(path)
    record["license"] = "test"
    record["version"] = "0.0"
    record.save(path)

    generator.run

    record = Licensed::DependencyRecord.read(path)
    assert_equal "test", record["license"]
    refute_equal "0.0", record["version"]
  end

  it "does not reuse nil record version" do
    generator.run

    path = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.read(path)
    record["license"] = "test"
    record.save(path)

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

    record = Licensed::DependencyRecord.read(path)
    assert_equal "test", record["license"]
    assert_equal "1.0", record["version"]
  end

  it "does not reuse empty record version" do
    generator.run

    path = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.read(path)
    record["license"] = "test"
    record["version"] = ""
    record.save(path)

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

    record = Licensed::DependencyRecord.read(path)
    assert_equal "test", record["license"]
    assert_equal "1.0", record["version"]
  end

  it "does not include ignored dependencies in dependency counts" do
    generator.run
    count = reporter.report.all_reports.size

    FileUtils.mkdir_p config.cache_path.join("test")
    File.write config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
    config.ignore "type" => "test", "name" => "dependency"

    generator.run
    ignored_count = reporter.report.all_reports.size
    assert_equal count - 1, ignored_count
  end

  it "reports a warning when a dependency doesn't exist" do
    config.apps.first["test"] = { path: File.join(Dir.pwd, "non-existant") }
    generator.run
    report = reporter.report.all_reports.find { |r| r.name&.include?("dependency") }
    refute_empty report.warnings
    assert report.warnings.any? { |w| w =~ /expected dependency path .*? does not exist/ }
  end

  it "reports an error when a dependency's path is empty" do
    config.apps.first["test"] = { path: nil }
    generator.run
    report = reporter.report.all_reports.find { |r| r.name&.include?("dependency") }
    assert_includes report.errors, "dependency path not found"
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
    let(:config) { Licensed::Configuration.new("source_path" => fixtures, "cache_path" => cache_path) }

    it "changes the current directory to app.source_path while running" do
      generator.run
      assert_equal fixtures, source.dependencies.first.record["dir"]
    end
  end

  describe "with explicit dependency file path" do
    let(:source) { TestSource.new(config, "dependency/path", "name" => "dependency", "cache_path" => cache_path) }

    it "caches metadata at the given file path" do
      generator.run
      assert config.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end
end
