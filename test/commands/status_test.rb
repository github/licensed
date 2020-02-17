# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::Status do
  let(:cache_path) { Dir.mktmpdir }
  let(:reporter) { TestReporter.new }
  let(:apps) { [] }
  let(:source_config) { {} }
  let(:config) { Licensed::Configuration.new("apps" => apps, "cache_path" => cache_path, "sources" => { "test" => true }, "test" => source_config) }
  let(:verifier) { Licensed::Commands::Status.new(config: config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
    Spy.on(verifier, :create_reporter).and_return(reporter)

    generator_config = Marshal.load(Marshal.dump(config))
    generator = Licensed::Commands::Cache.new(config: generator_config)
    Spy.on(generator, :create_reporter).and_return(TestReporter.new)
    generator.run(force: true)
  end

  after do
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end
  end

  def dependency_errors(app, source, dependency_name = "dependency")
    app_report = reporter.report.reports.find { |app_report| app_report.name == app["name"] }
    assert app_report

    source_report = app_report.reports.find { |source_report| source_report.target == source }
    assert source_report

    dependency_report = source_report.reports.find { |dependency_report| dependency_report.name.include?(dependency_name) }
    dependency_report&.errors || []
  end

  it "warns if license is not allowed" do
    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert_includes dependency_errors(app, source), "license needs review: mit"
      end
    end
  end

  it "does not warn if license is allowed" do
    config.apps.each do |app|
      app.allow "mit"
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        refute_includes dependency_errors(app, source), "license needs review: mit"
      end
    end
  end

  it "does not warn if dependency is ignored" do
    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert dependency_errors(app, source).any?
        app.ignore "type" => source.class.type, "name" => "dependency"
      end
    end

    verifier.run

    config.apps.each do |app|
      app.sources.each do |source|
        assert dependency_errors(app, source).empty?
      end
    end
  end

  it "does not warn if dependency is reviewed" do
    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert dependency_errors(app, source).any?
        app.ignore "type" => source.class.type, "name" => "dependency"
      end
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert dependency_errors(app, source).empty?
      end
    end
  end

  it "warns if license is empty" do
    config.apps.each do |app|
      filename = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.new
      record.save(filename)
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert_includes dependency_errors(app, source), "missing license text"
      end
    end
  end

  it "warns if record is empty with notices" do
    config.apps.each do |app|
      filename = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.new(notices: ["notice"])
      record.save(filename)
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert_includes dependency_errors(app, source), "missing license text"
      end
    end
  end

  it "does not warn if license is not empty" do
    config.apps.each do |app|
      filename = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.new(licenses: ["license"])
      record.save(filename)
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        refute_includes dependency_errors(app, source), "missing license text"
      end
    end
  end

  it "warns if versions do not match" do
    config.apps.each do |app|
      filename = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      record = Licensed::DependencyRecord.read(filename)
      record["version"] = "9001"
      record.save(filename)
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert_includes dependency_errors(app, source), "cached dependency record out of date"
      end
    end
  end

  it "warns if cached license data missing" do
    config.apps.each do |app|
      FileUtils.rm app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        assert_includes dependency_errors(app, source), "cached dependency record not found"
      end
    end
  end

  it "does not warn if cached license data missing for ignored gem" do
    config.apps.each do |app|
      FileUtils.rm app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
      app.ignore "type" => "test", "name" => "dependency"
    end

    verifier.run
    config.apps.each do |app|
      app.sources.each do |source|
        refute_includes dependency_errors(app, source), "cached dependency record not found"
      end
    end
  end

  it "does not include ignored dependencies in dependency counts" do
    verifier.run
    count = reporter.report.all_reports.size

    config.apps.each do |app|
      app.ignore "type" => "test", "name" => "dependency"
    end

    verifier.run
    ignored_count = reporter.report.all_reports.size

    assert_equal count - config.apps.size, ignored_count
  end

  it "changes the current directory to app.source_path while running" do
    config.apps.each do |app|
      app["source_path"] = fixtures
    end

    verifier.run

    reports = reporter.report.all_reports
    dependency_report = reports.find { |dependency| dependency.name == "licensed.test.dependency" }
    assert dependency_report
    assert_equal fixtures, dependency_report[:dependency].path
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

    it "verifies dependencies for all apps" do
      verifier.run
      apps.each do |app|
        assert reporter.report.reports.find { |report| report.name == app["name"] }
      end
    end
  end

  describe "with explicit dependency file path" do
    let(:source_config) { { name: "dependency/path" } }

    it "verifies content at explicit path" do
      config.apps.each do |app|
        filename = app.cache_path.join("test/dependency/path.#{Licensed::DependencyRecord::EXTENSION}")
        record = Licensed::DependencyRecord.new
        record.save(filename)
      end

      verifier.run
      config.apps.each do |app|
        app.sources.each do |source|
          assert_includes dependency_errors(app, source, "dependency/path"), "missing license text"
        end
      end
    end
  end

  describe "with multiple cached license notices" do
    let(:bsd_3) { Licensed::DependencyRecord::License.new(Licensee::License.find("bsd-3-clause").to_s) }
    let(:mit) { Licensed::DependencyRecord::License.new(Licensee::License.find("mit").to_s) }
    let(:agpl_3) { Licensed::DependencyRecord::License.new(Licensee::License.find("agpl-3.0").to_s) }
    let(:readme_mit) { Licensed::DependencyRecord::License.new("## License:\n\nMIT") }

    before do
      config.apps.each do |app|
        app.allow("mit")
        app.allow("bsd-3-clause")
      end
    end

    def update_records(classification, *licenses)
      config.apps.each do |app|
        path = app.cache_path.join("test/dependency.#{Licensed::DependencyRecord::EXTENSION}")
        record = Licensed::DependencyRecord.read(path)
        record.licenses.clear
        record.licenses.push(*licenses)
        record["license"] = classification
        record.save(path)
      end
    end

    it "does not warn if the top level license field is allowed" do
      # licenses contains an unapproved license notice (agpl-3.0), but should not be checked
      # because the top level license field is allowed
      update_records("mit", mit, agpl_3)

      verifier.run
      config.apps.each do |app|
        app.sources.each do |source|
          assert dependency_errors(app, source).empty?
        end
      end
    end

    it "warns if the top level license field is not allowed and not 'other'" do
      # both record license texts are approved, but licensed should only check
      # them when the record's top level license field is set to other
      update_records("agpl-3.0", mit, bsd_3)

      verifier.run
      config.apps.each do |app|
        app.sources.each do |source|
          assert_includes dependency_errors(app, source), "license needs review: agpl-3.0"
        end
      end
    end

    it "warns if any of the license notices is not allowed" do
      # licenses contains an unapproved license notice (agpl-3.0),
      # and will be checked because the top level license field is set to other
      update_records("other", mit, agpl_3)

      verifier.run
      config.apps.each do |app|
        app.sources.each do |source|
          assert_includes dependency_errors(app, source), "license needs review: other"
        end
      end
    end

    it "does not warn if all of the license notices are allowed" do
      # licenses contains only approved values, which pass status checks
      # when the top level license field is set to other
      update_records("other", mit, bsd_3)

      verifier.run
      config.apps.each do |app|
        app.sources.each do |source|
          assert dependency_errors(app, source).empty?
        end
      end
    end

    it "parses readme contents as well as license text" do
      # licenses includes content that will be matched as part of a README file,
      # but not as part of a LICENSE file
      update_records("other", readme_mit, bsd_3)

      verifier.run
      config.apps.each do |app|
        app.sources.each do |source|
          assert dependency_errors(app, source).empty?
        end
      end
    end
  end
end
