# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::NoticesReporter do
  let(:cache_path) { Dir.mktmpdir }
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::NoticesReporter.new(shell) }

  let(:command) { TestCommand.new(config: nil) }
  let(:app) { Licensed::AppConfiguration.new("source_path" => Dir.pwd, "cache_path" => cache_path) }
  let(:source) { TestSource.new(app) }
  let(:dependency) { source.dependencies.first }

  let(:report) { Licensed::Report.new(name: "report", target: nil) }

  after do
    FileUtils.rm_rf app.cache_path
  end

  describe "#begin_report_app" do
    it "prints an informative message to the shell" do
      reporter.begin_report_app(app, report)

      path = app.cache_path.join("NOTICE")
      assert_includes shell.messages,
                      {
                          message: "Writing notices for #{app["name"]} to #{path}",
                          newline: true,
                          style: :info
                      }
    end
  end

  describe "#end_report_app" do
    let(:dependency_report) { Licensed::Report.new(name: dependency.name, target: dependency) }

    before do
      report.reports << dependency_report
    end

    it "prints a warning if dependency notice contents can't be parsed" do
      dependency_report["cached_record"] = Licensed::DependencyRecord.new(
        licenses: [],
        notices: [1]
      )

      reporter.end_report_app(app, report)
      assert_includes shell.messages,
                      {
                          message: "* unable to parse notices for #{dependency.name}",
                          newline: true,
                          style: :warn
                      }
    end

    it "writes dependencies' licenses and notices to a NOTICE file" do
      dependency_report["cached_record"] = Licensed::DependencyRecord.new(
        licenses: [
          { "sources" => "LICENSE1", "text" => "license1" },
          { "sources" => "LICENSE2", "text" => "license2" }
        ],
        notices: [
          "notice1",
          { "sources" => "NOTICE", "text" => "notice2" }
        ]
      )

      reporter.end_report_app(app, report)
      path = app.cache_path.join("NOTICE")
      assert File.exist?(path)
      notices_contents = File.read(path)
      assert_includes notices_contents, "license1"
      assert_includes notices_contents, "license2"
      assert_includes notices_contents, "notice1"
      assert_includes notices_contents, "notice2"
    end

    it "writes dependencies' licenses and notices to a NOTICE.<app> file in a shared cache" do
      app["shared_cache"] = true
      dependency_report["cached_record"] = Licensed::DependencyRecord.new(
        licenses: [
          { "sources" => "LICENSE1", "text" => "license1" },
          { "sources" => "LICENSE2", "text" => "license2" }
        ],
        notices: [
          "notice1",
          { "sources" => "NOTICE", "text" => "notice2" }
        ]
      )

      reporter.end_report_app(app, report)

      path = app.cache_path.join("NOTICE.#{app["name"]}")
      assert File.exist?(path)
      notices_contents = File.read(path)
      assert_includes notices_contents, "license1"
      assert_includes notices_contents, "license2"
      assert_includes notices_contents, "notice1"
      assert_includes notices_contents, "notice2"
    end
  end

  describe "#end_report_source" do
    it "prints a warning from a source report" do
      report.warnings << "warning"
      reporter.end_report_source(source, report)
      assert_includes shell.messages,
                      {
                        message: "* #{report.name}: warning",
                        newline: true,
                        style: :warn
                      }
    end
  end

  describe "#end_report_dependency" do
    it "prints a warning from a dependency report" do
      report.warnings << "warning"
      reporter.end_report_dependency(dependency, report)
      assert_includes shell.messages,
                      {
                        message: "* #{report.name}: warning",
                        newline: true,
                        style: :warn
                      }
    end
  end
end
