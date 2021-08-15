# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::CacheReporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::CacheReporter.new(shell) }

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
                          message: "Caching dependency records for #{app["name"]}",
                          newline: true,
                          style: :info
                      }
    end
  end

  describe "#begin_report_source" do
    let(:report) { Licensed::Report.new(name: "source", target: source) }

    it "prints informative messages to the shell" do
      reporter.begin_report_source(source, report)
      assert_includes shell.messages,
                      {
                          message: "  #{source.class.type}",
                          newline: true,
                          style: :info
                      }
    end
  end

  describe "#end_report_source" do
    let(:report) { Licensed::Report.new(name: "source", target: source) }
    let(:dependency_report) { Licensed::Report.new(name: "dependency", target: dependency) }

    before do
      report.reports << dependency_report
    end

    it "reports the number of dependencies when no errors are reported" do
      reporter.end_report_source(source, report)
      assert_includes shell.messages,
                      {
                          message: "  * 1 #{source.class.type} dependencies",
                          newline: true,
                          style: :confirm
                      }
    end

    it "reports warnings during the source run" do
      dependency_report.warnings << "dependency warning"
      reporter.end_report_source(source, report)

      assert_includes shell.messages,
                      {
                          message: "      - dependency warning",
                          newline: true,
                          style: :warn
                      }

      assert_includes shell.messages,
                      {
                          message: "  * 1 #{source.class.type} dependencies",
                          newline: true,
                          style: :confirm
                      }
    end

    it "reports dependency errors during the source run" do
      dependency_report.errors << "dependency error"
      reporter.end_report_source(source, report)
      assert_includes shell.messages,
                      {
                          message: "      - dependency error",
                          newline: true,
                          style: :error
                      }

      refute_includes shell.messages,
                      {
                          message: "  * 1 #{source.class.type} dependencies",
                          newline: true,
                          style: :confirm
                      }
    end

    it "reports source errors during the source run" do
      report.errors << "source error"
      reporter.end_report_source(source, report)

      assert_includes shell.messages,
                      {

                          message: "      - source error",
                          newline: true,
                          style: :error
                      }

      refute_includes shell.messages,
                      {
                          message: "  * 1 #{source.class.type} dependencies",
                          newline: true,
                          style: :confirm
                      }
    end
  end

  describe "#end_report_dependency" do
    let(:report) { Licensed::Report.new(name: dependency.name, target: dependency) }

    it "prints an informative messages for a cached dependency to the shell" do
      report["cached"] = true
      reporter.end_report_dependency(dependency, report)
      assert_includes shell.messages,
                      {
                          message: "    Caching #{dependency.name} (#{dependency.version})",
                          newline: true,
                          style: :info
                      }
    end

    it "prints an informative messages for a skipped dependency to the shell" do
      report["cached"] = false
      reporter.end_report_dependency(dependency, report)
      assert_includes shell.messages,
                      {
                          message: "    Using #{dependency.name} (#{dependency.version})",
                          newline: true,
                          style: :info
                      }
    end

    it "prints an informative messages for an errored dependency to the shell" do
      report.errors << "error"
      reporter.end_report_dependency(dependency, report)
      assert_includes shell.messages,
                      {
                          message: "    Error #{dependency.name} (#{dependency.version})",
                          newline: true,
                          style: :error
                      }
    end
  end
end
