# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::List do
  let(:reporter) { TestReporter.new }
  let(:apps) { [] }
  let(:source_config) { {} }
  let(:config) { Licensed::Configuration.new("apps" => apps, "sources" => { "test" => true }, "test" => source_config) }
  let(:command) { Licensed::Commands::List.new(config: config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
    Spy.on(command, :create_reporter).and_return(reporter)
  end

  each_source do |source_class|
    describe "with #{source_class.type}" do
      let(:source_type) { source_class.type }
      let(:config_file) { File.join(fixtures, "command/#{source_type}.yml") }
      let(:config) { Licensed::Configuration.load_from(config_file) }

      it "lists dependencies" do
        config.apps.each do |app|
          enabled = Dir.chdir(app.source_path) { app.sources.any? { |source| source.enabled? } }
          next unless enabled

          command.run
          app_report = reporter.report.reports.find { |app_report| app_report.target == app }
          assert app_report

          app.sources.each do |source|
            source_report = app_report.reports.find { |source_report| source_report.target == source }
            assert source_report

            expected_dependency = app["expected_dependency"]
            assert source_report.reports.find { |dependency_report| dependency_report.name.include?(expected_dependency) }
          end
        end
      end
    end
  end

  it "does not include ignored dependencies" do
    command.run
    dependencies = reporter.report.all_reports
    assert dependencies.any? { |dependency| dependency.name == "licensed.test.dependency" }
    count = dependencies.size

    config.apps.each do |app|
      app.ignore("type" => "test", "name" => "dependency")
    end

    command.run
    dependencies = reporter.report.all_reports
    refute dependencies.any? { |dependency| dependency.name == "licensed.test.dependency" }
    ignored_count = dependencies.size

    assert_equal count - config.apps.size, ignored_count
  end

  it "changes the current directory to app.source_path while running" do
    config.apps.each do |app|
      app["source_path"] = fixtures
    end

    command.run

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

    it "lists dependencies for all apps" do
      command.run
      config.apps.each do |app|
        assert reporter.report.reports.find { |report| report.name == app["name"] }
      end
    end
  end
end
