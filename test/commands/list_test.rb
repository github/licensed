# frozen_string_literal: true
require "test_helper"
require "test_helpers/command_test_helpers"

describe Licensed::Commands::List do
  include CommandTestHelpers

  let(:reporter) { TestReporter.new }
  let(:apps) { [] }
  let(:source_config) { {} }
  let(:config) { Licensed::Configuration.new("apps" => apps, "sources" => { "test" => true }, "test" => source_config) }
  let(:command) { Licensed::Commands::List.new(config: config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  each_source do |source_class|
    describe "with #{source_class.full_type}" do
      let(:source_type) { source_class.full_type }
      let(:config_file) { File.join(fixtures, "#{source_type}/.licensed.yml") }
      let(:config) { Licensed::Configuration.load_from(config_file) }

      it "lists dependencies" do
        config.apps.each do |app|
          source = app.sources.find { |s| s.class == source_class }
          next unless Dir.chdir(app.source_path) { source.enabled? }

          run_command
          app_report = reporter.report.reports.find { |r| r.target == app }
          assert app_report

          source_report = app_report.reports.find { |r| r.target == source }
          assert source_report

          expected_dependency = app["expected_dependency"]
          assert source_report.reports.find { |r| r.name.include?(expected_dependency) }
        end
      end
    end
  end

  it "does not include ignored dependencies" do
    run_command
    dependencies = reporter.report.all_reports
    assert dependencies.any? { |dependency| dependency.name == "licensed.test.dependency" }
    count = dependencies.size

    config.apps.each do |app|
      app.ignore("type" => "test", "name" => "dependency")
    end

    run_command
    dependencies = reporter.report.all_reports
    refute dependencies.any? { |dependency| dependency.name == "licensed.test.dependency" }
    ignored_count = dependencies.size

    assert_equal count - config.apps.size, ignored_count
  end

  it "changes the current directory to app.source_path while running" do
    config.apps.each do |app|
      app["source_path"] = fixtures
    end

    run_command

    reports = reporter.report.all_reports
    dependency_report = reports.find { |report| report.target.is_a?(Licensed::Dependency) }
    assert dependency_report
    assert_equal fixtures, dependency_report.target.path
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

    it "lists dependencies for all apps" do
      run_command
      config.apps.each do |app|
        assert reporter.report.reports.find { |report| report.name == app["name"] }
      end
    end
  end

  it "sets the dependency version in dependency reports" do
    run_command
    dependencies = reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::Dependency) }
    assert dependencies.all? { |dependency| dependency["version"] }
  end

  describe "detected license key" do
    it "is not included in dependency reports by default" do
      run_command
      dependencies = reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::Dependency) }
      refute dependencies.any? { |dependency| dependency["license"] }
    end

    it "is included in dependency reports if the license CLI flag is set" do
      run_command(licenses: true)
      dependencies = reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::Dependency) }
      assert dependencies.all? { |dependency| dependency["license"] }
    end
  end
end
