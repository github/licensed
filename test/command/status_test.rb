# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::Status do
  let(:reporter) { TestReporter.new }
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new(config) }
  let(:verifier) { Licensed::Command::Status.new(config, reporter) }

  before do
    config.apps.each do |app|
      app.sources.clear
      app.sources << source
    end

    config.ui.silence do
      Licensed::Command::Cache.new(config.dup, reporter).run(force: true)
    end
  end

  after do
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end
  end

  def dependency_errors(dependency_name = "dependency")
    source_results = reporter.results.values.first[source.class.type]
    dependency_results = source_results[dependency_name]
    return [] if dependency_results.nil?
    dependency_results["errors"] || []
  end

  it "warns if license is not allowed" do
    verifier.run
    assert_includes dependency_errors, "license needs reviewed: mit"
  end

  it "does not warn if license is allowed" do
    config.allow "mit"
    verifier.run
    refute_includes dependency_errors, "license needs reviewed: mit"
  end

  it "does not warn if dependency is ignored" do
    verifier.run
    assert dependency_errors.any?

    config.ignore "type" => "test", "name" => "dependency"
    verifier.run

    assert dependency_errors.empty?
  end

  it "does not warn if dependency is reviewed" do
    verifier.run
    assert dependency_errors.any?

    config.review "type" => "test", "name" => "dependency"
    verifier.run
    assert dependency_errors.empty?
  end

  it "warns if license is empty" do
    filename = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.new
    record.save(filename)

    verifier.run
    assert_includes dependency_errors, "missing license text"
  end

  it "warns if record is empty with notices" do
    filename = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.new(notices: ["notice"])
    record.save(filename)

    verifier.run
    assert_includes dependency_errors, "missing license text"
  end

  it "does not warn if license is not empty" do
    filename = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.new(licenses: ["license"])
    record.save(filename)

    verifier.run
    refute_includes dependency_errors, "missing license text"
  end

  it "warns if versions do not match" do
    filename = config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    record = Licensed::DependencyRecord.read(filename)
    record["version"] = "9001"
    record.save(filename)

    verifier.run
    assert_includes dependency_errors, "cached license data out of date"
  end

  it "warns if cached license data missing" do
    FileUtils.rm config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    verifier.run
    assert_includes dependency_errors, "cached license data missing"
  end

  it "does not warn if cached license data missing for ignored gem" do
    FileUtils.rm config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    config.ignore "type" => "test", "name" => "dependency"

    verifier.run
    refute_includes dependency_errors, "cached license data missing"
  end

  it "does not include ignored dependencies in dependency counts" do
    verifier.run
    count = reporter.results.flat_map { |_, source_results| source_results.values }
                            .reduce(&:merge)
                            .size

    config.ignore "type" => "test", "name" => "dependency"
    verifier.run
    ignored_count = reporter.results.flat_map { |_, source_results| source_results.values }
                                    .reduce(&:merge)
                                    .size

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

    it "verifies dependencies for all apps" do
      verifier.run
      apps.each do |app|
        assert_includes reporter.results.keys, app["name"]
      end
    end
  end

  describe "with app.source_path" do
    let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      verifier.run
      assert_equal fixtures, source.dependencies.first.record["dir"]
    end
  end

  describe "with explicit dependency file path" do
    let(:source) { TestSource.new(config, "dependency/path", "name" => "dependency") }

    it "verifies content at explicit path" do
      filename = config.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.new
      record.save(filename)

      verifier.run
      assert_includes dependency_errors("dependency/path"), "missing license text"
    end
  end
end
