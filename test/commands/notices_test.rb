# frozen_string_literal: true
require "test_helper"
require "test_helpers/command_test_helpers"

describe Licensed::Commands::Notices do
  include CommandTestHelpers

  let(:cache_path) { Dir.mktmpdir }
  let(:reporter) { TestReporter.new }
  let(:config) { Licensed::Configuration.new("cache_path" => cache_path, "sources" => { "test" => true }) }
  let(:command) { Licensed::Commands::Notices.new(config:) }

  before do
    generator_config = Marshal.load(Marshal.dump(config))
    generator = Licensed::Commands::Cache.new(config: generator_config)
    generator.run(force: true, reporter: TestReporter.new)
  end

  after do
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end
  end

  def dependency_report(app, source, dependency_name = "dependency")
    app_report = reporter.report.reports.find { |r| r.name == app["name"] }
    assert app_report

    source_report = app_report.reports.find { |r| r.target == source }
    assert source_report

    source_report.reports.find { |dependency_report| dependency_report.name.include?(dependency_name) }
  end

  it "reports cached records found for dependencies" do
    run_command

    config.apps.each do |app|
      app.sources.each do |source|
        source.dependencies.each do |dependency|
          report = dependency_report(app, source, dependency.name)
          assert report
          assert_equal dependency.record["name"], report["record"]["name"]
          assert_equal dependency.record["version"], report["record"]["version"]
          assert_equal dependency.record.content, report["record"].content
        end
      end
    end
  end

  it "reports computed records found for dependencies" do
    # delete all cached files for dependencies
    config.apps.each do |app|
      FileUtils.rm_rf app.cache_path
    end

    run_command(computed: true)

    config.apps.each do |app|
      app.sources.each do |source|
        source.dependencies.each do |dependency|
          report = dependency_report(app, source, dependency.name)
          assert report
          assert_equal dependency.record["name"], report["record"]["name"]
          assert_equal dependency.record["version"], report["record"]["version"]
          assert_equal dependency.record.content, report["record"].content
        end
      end
    end
  end

  it "reports a warning on missing records" do
    config.apps.each { |app| FileUtils.rm_rf app.cache_path }
    run_command

    config.apps.each do |app|
      app.sources.each do |source|
        source.dependencies.each do |dependency|
          report = dependency_report(app, source, dependency.name)
          assert report
          assert_nil report["record"]
          path = app.cache_path.join(source.class.type, "#{dependency.name}.#{Licensed::DependencyRecord::EXTENSION}")
          assert_equal ["expected cached record not found at #{path}"],
                       report.warnings
        end
      end
    end
  end
end
