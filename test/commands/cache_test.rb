# frozen_string_literal: true
require "test_helper"
require "test_helpers/command_test_helpers"

describe Licensed::Commands::Cache do
  include CommandTestHelpers

  let(:cache_path) { Dir.mktmpdir }
  let(:apps) { [] }
  let(:source_config) { {} }
  let(:config) { Licensed::Configuration.new("apps" => apps, "cache_path" => cache_path, "sources" => { "test" => true }, "test" => source_config) }
  let(:reporter) { TestReporter.new }
  let(:command) { Licensed::Commands::Cache.new(config: config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  after do
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end
  end

  each_source do |source_class|
    describe "with #{source_class.full_type}" do
      let(:source_type) { source_class.full_type }
      let(:config_file) { File.join(fixtures, "command/#{source_type}.yml") }
      let(:config) { Licensed::Configuration.load_from(config_file) }

      it "extracts license info" do
        config.apps.each do |app|
          source = app.sources.find { |s| s.class == source_class }
          next unless Dir.chdir(app.source_path) { source.enabled? }

          run_command

          expected_dependency = app["expected_dependency"]
          expected_dependency_name = app["expected_dependency_name"] || expected_dependency
          path = app.cache_path.join("#{source_class.type}/#{expected_dependency}.#{Licensed::DependencyRecord::EXTENSION}")
          assert path.exist?
          record = Licensed::DependencyRecord.read(path)
          assert_equal expected_dependency_name, record["name"]
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

    run_command

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

    run_command

    config.apps.each do |app|
      refute app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end

  it "does not clean up dependencies from shared caches" do
    apps << { "source_path" => Dir.pwd, "cache_path" => cache_path, "test" => { name: 1 } }
    apps << { "source_path" => Dir.pwd, "cache_path" => cache_path, "test" => { name: 2 } }

    run_command

    files = Dir.glob(File.join(cache_path, "**/*.#{Licensed::DependencyRecord::EXTENSION}"))
               .map(&File.method(:basename))
               .map { |file| file.chomp(".#{Licensed::DependencyRecord::EXTENSION}") }
               .sort
    assert_equal files, ["1", "2"]
  end

  it "does not clean up dependencies outside of sources' cache paths" do
    config.apps.each do |app|
      FileUtils.mkdir_p app.cache_path.join("other")
      File.write app.cache_path.join("root.#{Licensed::DependencyRecord::EXTENSION}"), ""
      File.write app.cache_path.join("other", "dep.#{Licensed::DependencyRecord::EXTENSION}"), ""
    end

    run_command

    config.apps.each do |app|
      assert app.cache_path.join("root.#{Licensed::DependencyRecord::EXTENSION}").exist?
      assert app.cache_path.join("other", "dep.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end

  it "does not clean up dependencies from skipped sources" do
    config.apps.each do |app|
      FileUtils.mkdir_p app.cache_path.join("test")
      File.write app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
    end

    run_command(sources: ["other"])

    config.apps.each do |app|
      assert app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
    end
  end

  it "uses cached record if license text does not change" do
    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record["license"] = "test"
      record["version"] = "0.0"
      record.save(path)
    end

    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal "test", record["license"]
      refute_equal "0.0", record["version"]
    end
  end

  it "requires re-review after license text changes" do
    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record.licenses.clear
      record["version"] = "0.0"
      record.save(path)

      # set the app reviewed to trigger the need for re-review
      app.review(record)
    end

    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal true, record["review_changed_license"]
      refute_equal "0.0", record["version"]
    end
  end

  it "does not reuse nil record version" do
    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record["version"] = nil
      record["license"] = "test"
      record.save(path)
    end

    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal "test", record["license"]
      assert_equal "1.0", record["version"]
    end
  end

  it "does not reuse empty record version" do
    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      record["license"] = "test"
      record["version"] = ""
      record.save(path)
    end

    run_command

    config.apps.each do |app|
      path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(path)
      assert_equal "test", record["license"]
      assert_equal "1.0", record["version"]
    end
  end

  it "does not include ignored dependencies in dependency counts" do
    run_command
    count = reporter.report.all_reports.size

    config.apps.each do |app|
      FileUtils.mkdir_p app.cache_path.join("test")
      File.write app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}"), ""
      app.ignore "type" => "test", "name" => "dependency"
    end

    run_command
    ignored_count = reporter.report.all_reports.size
    assert_equal count - config.apps.size, ignored_count
  end

  it "reports a warning when a dependency doesn't exist" do
    source_config[:path] = File.join(Dir.pwd, "non-existant")
    run_command
    report = reporter.report.all_reports.find { |r| r.name&.include?("dependency") }
    refute_empty report.warnings
    assert report.warnings.any? { |w| w =~ /expected dependency path .*? does not exist/ }
  end

  it "reports an error when a dependency's path is empty" do
    source_config[:path] = nil
    run_command
    report = reporter.report.all_reports.find { |r| r.name&.include?("dependency") }
    assert_includes report.errors, "dependency path not found"
  end

  it "reports the detected license" do
    run_command
    report = reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    assert_equal "mit", report["license"]
  end

  it "reports the cached file name" do
    run_command
    report = reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    assert report["filename"].end_with? "test/dependency.#{Licensed::DependencyRecord::EXTENSION}"
  end

  it "reports whether the cached metadata file was updated" do
    run_command
    report = reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    assert report["cached"]

    reporter.report.all_reports.clear

    run_command
    report = reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    refute report["cached"]
  end

  it "reports the dependency version" do
    run_command
    report = reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    assert_equal "1.0", report["version"]
  end

  it "changes the current directory to app.source_path while running" do
    config.apps.each do |app|
      app["source_path"] = fixtures
    end

    run_command

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
      run_command
      config.apps.each do |app|
        assert app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
        assert app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}").exist?
      end
    end
  end

  describe "with explicit dependency file path" do
    let(:source_config) { { name: "dependency/path" } }

    it "caches metadata at the given file path" do
      run_command
      config.apps.each do |app|
        assert app.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}").exist?
      end
    end
  end
end
