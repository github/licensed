# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::YamlReporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::YamlReporter.new(shell) }
  let(:report) { Licensed::Report.new(name: "report", target: nil) }

  let(:command) { TestCommand.new(config: nil) }
  let(:app) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:source) { TestSource.new(app) }
  let(:dependency) { source.dependencies.first }

  describe "#end_report_command" do
    it "prints any data set as YAML format" do
      report["key"] = "test"
      reporter.end_report_command(command, report)

      expected_object = {
        "name" => "report",
        "key" => "test"
      }
      assert_includes shell.messages,
                      {
                         message: expected_object.to_yaml,
                         newline: true,
                         style: :info
                      }
    end
  end

  describe "#end_report_app" do
    it "sets source report data to the application report" do
      source_report = Licensed::Report.new(name: "source", target: source)
      source_report["test_data"] = "data"
      report.reports << source_report

      assert_nil report["sources"]

      reporter.end_report_app(app, report)

      assert_equal [source_report.to_h], report["sources"]
    end
  end

  describe "#end_report_source" do
    it "sets dependency report data to the source report" do
      dependency_report = Licensed::Report.new(name: "source", target: source)
      dependency_report["test_data"] = "data"
      report.reports << dependency_report

      assert_nil report["dependencies"]

      reporter.end_report_source(app, report)

      assert_equal [dependency_report.to_h], report["dependencies"]
    end
  end
end
