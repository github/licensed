# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::StatusReporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::StatusReporter.new(shell) }

  let(:command) { TestCommand.new(config: nil) }
  let(:app) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:source) { TestSource.new(app) }
  let(:dependency) { source.dependencies.first }

  describe "#begin_report_app" do
    let(:report) { Licensed::Report.new(name: app["name"], target: app) }

    it "prints an informative message to the shell" do
      reporter.begin_report_app(app, report)
      assert_includes shell.messages,
                      {
                          message: "Checking cached dependency records for #{app["name"]}",
                          newline: true,
                          style: :info
                      }
    end
  end

  describe "#end_report_app" do
    let(:report) { Licensed::Report.new(name: app["name"], target: app) }
    let(:dependency_report) { Licensed::Report.new(name: dependency.name, target: dependency) }

    before do
      report.reports << dependency_report
    end

    it "reports the number of dependencies and errors found" do
      dependency_report.errors << "error1"
      dependency_report.errors << "error2"
      reporter.end_report_app(app, report)

      assert_includes shell.messages,
                      {
                          message: "1 dependencies checked, 2 errors found.",
                          newline: true,
                          style: :info
                      }
    end

    it "reports dependencies with errors found during an app run" do
      dependency_report["meta1"] = "data1"
      dependency_report["meta2"] = "data2"
      dependency_report.errors << "error1"
      dependency_report.errors << "error2"
      reporter.end_report_app(app, report)

      assert_includes shell.messages,
                      {
                          message: "* #{dependency_report.name}",
                          newline: true,
                          style: :error
                      }

      assert_includes shell.messages,
                      {
                          message: "  meta1: data1, meta2: data2",
                          newline: true,
                          style: :error
                      }

      assert_includes shell.messages,
                      {
                          message: "    - error1",
                          newline: true,
                          style: :error
                      }

      assert_includes shell.messages,
                      {
                          message: "    - error2",
                          newline: true,
                          style: :error
                      }
    end

    it "reports dependencies with warnings found during an app run" do
      dependency_report["meta1"] = "data1"
      dependency_report["meta2"] = "data2"
      dependency_report.warnings << "warning1"
      dependency_report.warnings << "warning2"
      reporter.end_report_app(app, report)

      assert_includes shell.messages,
                      {
                          message: "* #{dependency_report.name}",
                          newline: true,
                          style: :warn
                      }

      assert_includes shell.messages,
                      {
                          message: "  meta1: data1, meta2: data2",
                          newline: true,
                          style: :warn
                      }

      assert_includes shell.messages,
                      {
                        message: "    - warning1",
                        newline: true,
                        style: :warn
                      }

      assert_includes shell.messages,
                      {
                        message: "    - warning2",
                        newline: true,
                        style: :warn
                      }
    end
  end

  describe "#end_report_dependency" do
    let(:report) { Licensed::Report.new(name: dependency.name, target: dependency) }

    it "prints an 'F' error if result has errors" do
      report.errors << "error"
      reporter.end_report_dependency(dependency, report)
      assert_includes shell.messages,
                      {
                          message: "F",
                          newline: false,
                          style: :error
                      }
    end

    it "prints an '.' success if result does not have errors" do
      reporter.end_report_dependency(dependency, report)
      assert_includes shell.messages,
                      {
                          message: ".",
                          newline: false,
                          style: :confirm
                      }
    end
  end
end
