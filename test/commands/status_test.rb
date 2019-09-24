# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::Status do
  let(:cache_path) { Dir.mktmpdir }
  let(:reporter) { TestReporter.new }
  let(:config) { Licensed::Configuration.new("cache_path" => cache_path) }
  let(:source) { TestSource.new(config) }
  let(:verifier) { Licensed::Commands::Status.new(config: config, reporter: reporter) }

  before do
    config.apps.each do |app|
      app.sources.clear
      app.sources << source
    end

    Licensed::Commands::Cache.new(config: config.dup, reporter: reporter).run(force: true)
  end

  after do
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end
  end

  def dependency_errors(dependency_name = "dependency")
    app_report = reporter.report.reports.find { |app_report| app_report.name == config["name"] }
    assert app_report

    source_report = app_report.reports.find { |source_report| source_report.target == source }
    assert source_report

    dependency_report = source_report.reports.find { |dependency_report| dependency_report.name.include?(dependency_name) }
    dependency_report&.errors || []
  end

  it "warns if license is not allowed" do
    verifier.run
    assert_includes dependency_errors, "license needs review: mit"
  end

  it "does not warn if license is allowed" do
    config.allow "mit"
    verifier.run
    refute_includes dependency_errors, "license needs review: mit"
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
    assert_includes dependency_errors, "cached dependency record out of date"
  end

  it "warns if cached license data missing" do
    FileUtils.rm config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    verifier.run
    assert_includes dependency_errors, "cached dependency record not found"
  end

  it "does not warn if cached license data missing for ignored gem" do
    FileUtils.rm config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    config.ignore "type" => "test", "name" => "dependency"

    verifier.run
    refute_includes dependency_errors, "cached license data missing"
  end

  it "does not include ignored dependencies in dependency counts" do
    verifier.run
    count = reporter.report.all_reports.size

    config.ignore "type" => "test", "name" => "dependency"
    verifier.run
    ignored_count = reporter.report.all_reports.size

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
        assert reporter.report.reports.find { |report| report.name == app["name"] }
      end
    end
  end

  describe "with app.source_path" do
    let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }
    let(:config) { Licensed::Configuration.new("source_path" => fixtures, "cache_path" => cache_path) }

    it "changes the current directory to app.source_path while running" do
      verifier.run
      assert_equal fixtures, source.dependencies.first.record["dir"]
    end
  end

  describe "with explicit dependency file path" do
    let(:source) { TestSource.new(config, "dependency/path", "name" => "dependency", "cache_path" => cache_path) }

    it "verifies content at explicit path" do
      filename = config.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.new
      record.save(filename)

      verifier.run
      assert_includes dependency_errors("dependency/path"), "missing license text"
    end
  end

  describe "with multiple cached license notices" do
    let(:bsd_3) { Licensed::DependencyRecord::License.new(Licensee::License.find("bsd-3-clause").to_s) }
    let(:mit) { Licensed::DependencyRecord::License.new(Licensee::License.find("mit").to_s) }
    let(:agpl_3) { Licensed::DependencyRecord::License.new(Licensee::License.find("agpl-3.0").to_s) }
    let(:readme_mit) { Licensed::DependencyRecord::License.new("## License:\n\nMIT") }
    let(:record_file) { config.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}") }
    let(:record) { Licensed::DependencyRecord.read(record_file) }

    before do
      config.allow("mit")
      config.allow("bsd-3-clause")

      record.licenses.clear
    end

    it "does not warn if the top level license field is allowed" do
      # licenses contains an unapproved license notice (agpl-3.0), but should not be checked
      # because the top level license field is allowed
      record.licenses.push(mit, agpl_3)
      record["license"] = "mit"
      record.save(record_file)

      verifier.run
      assert dependency_errors.empty?
    end

    it "warns if the top level license field is not allowed and not 'other'" do
      record.licenses.push(mit, bsd_3)
      # both record license texts are approved, but licensed should only check
      # them when the record's top level license field is set to other
      record["license"] = "agpl-3.0"
      record.save(record_file)

      verifier.run
      assert_includes dependency_errors, "license needs review: agpl-3.0"
    end

    it "warns if any of the license notices is not allowed" do
      # licenses contains an unapproved license notice (agpl-3.0),
      # and will be checked because the top level license field is set to other
      record.licenses.push(mit, agpl_3)
      record["license"] = "other"
      record.save(record_file)

      verifier.run
      assert_includes dependency_errors, "license needs review: other"
    end

    it "does not warn if all of the license notices are allowed" do
      # licenses contains only approved values, which pass status checks
      # when the top level license field is set to other
      record.licenses.push(mit, bsd_3)
      record["license"] = "other"
      record.save(record_file)

      verifier.run
      assert dependency_errors.empty?
    end

    it "parses readme contents as well as license text" do
      # licenses includes content that will be matched as part of a README file,
      # but not as part of a LICENSE file
      record.licenses.push(readme_mit, bsd_3)
      record["license"] = "other"
      record.save(record_file)

      verifier.run
      assert dependency_errors.empty?
    end
  end
end
