# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::Cache do
  let(:cache_path) { Dir.mktmpdir }
  let(:reporter) { TestReporter.new }
  let(:apps) { [] }
  let(:source_config) { {} }
  let(:config) { Licensed::Configuration.new("apps" => apps, "cache_path" => cache_path, "sources" => { "test" => true }, "test" => source_config) }
  let(:generator) { Licensed::Commands::Cache.new(config: config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
    Spy.on(generator, :create_reporter).and_return(reporter)
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

      it "extracts license info" do
        config.apps.each do |app|
          enabled = Dir.chdir(app.source_path) { app.sources.any? { |source| source.enabled? } }
          next unless enabled

          generator.run

          expected_dependency = app["expected_dependency"]
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
    config.apps.each do |app|
      FileUtils.mkdir_p app.cache_path.join("test")
      File.write app.cache_path.join("test/old_dep.#{Licensed::DependencyRecord::EXTENSION}"), ""
    end

    generator.run

    config.apps.each do |app|
      refute app.cache_path.join("test/old_dep.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end

  it "cleans up ignored dependencies" do
    config.apps.each do |app|
      FileUtils.mkdir_p app.cache_path.join("test")
      File.write app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
      app.ignore "type" => "test", "name" => "dependency"
    end

    generator.run

    config.apps.each do |app|
      refute app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end

  it "uses cached record if license text does not change" do
    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record["license"] = "test"
      record["version"] = "0.0"
      record.save(path)
    end

    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal "test", record["license"]
      refute_equal "0.0", record["version"]
    end
  end

  it "does not reuse nil record version" do
    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record["version"] = nil
      record["license"] = "test"
      record.save(path)
    end

    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal "test", record["license"]
      assert_equal "1.0", record["version"]
    end
  end

  it "does not reuse empty record version" do
    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record["license"] = "test"
      record["version"] = ""
      record.save(path)
    end

    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal "test", record["license"]
      assert_equal "1.0", record["version"]
    end
  end

  it "does not include ignored dependencies in dependency counts" do
    generator.run
    count = reporter.report.all_reports.size

    config.apps.each do |app|
      FileUtils.mkdir_p app.cache_path.join("test")
      File.write app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
      app.ignore "type" => "test", "name" => "dependency"
    end

    generator.run
    ignored_count = reporter.report.all_reports.size
    assert_equal count - config.apps.size, ignored_count
  end

  it "reports a warning when a dependency doesn't exist" do
    source_config[:path] = File.join(Dir.pwd, "non-existant")
    generator.run
    report = reporter.report.all_reports.find { |r| r.name&.include?("dependency") }
    refute_empty report.warnings
    assert report.warnings.any? { |w| w =~ /expected dependency path .*? does not exist/ }
  end

  it "reports an error when a dependency's path is empty" do
    source_config[:path] = nil
    generator.run
    report = reporter.report.all_reports.find { |r| r.name&.include?("dependency") }
    assert_includes report.errors, "dependency path not found"
  end

  it "changes the current directory to app.source_path while running" do
    config.apps.each do |app|
      app["source_path"] = fixtures
    end

    generator.run

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal fixtures, record["dir"]
    end
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

    it "caches metadata for all apps" do
      generator.run
      config.apps.each do |app|
        assert app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
        assert app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
      end
    end
  end

  describe "with explicit dependency file path" do
    let(:source_config) { { name: "dependency/path" } }

    it "caches metadata at the given file path" do
      generator.run
      config.apps.each do |app|
        assert app.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}").exist?
      end
    end
  end
end
