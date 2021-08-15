# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::Reporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::Reporter.new(shell) }
  let(:report) { Licensed::Report.new(name: "report", target: nil) }

  let(:command) { TestCommand.new(config: nil) }
  let(:app) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:source) { TestSource.new(app) }
  let(:dependency) { source.dependencies.first }

  describe "#begin_report_command" do
    it "does nothing by default" do
      reporter.begin_report_command(command, report)
      assert shell.messages.empty?
    end
  end

  describe "#end_report_command" do
    it "does nothing by default" do
      reporter.end_report_command(command, report)
      assert shell.messages.empty?
    end
  end

  describe "#begin_report_app" do
    it "does nothing by default" do
      reporter.begin_report_app(app, report)
      assert shell.messages.empty?
    end
  end

  describe "#end_report_app" do
    it "does nothing by default" do
      reporter.end_report_app(app, report)
      assert shell.messages.empty?
    end
  end

  describe "#begin_report_source" do
    it "does nothing by default" do
      reporter.begin_report_source(source, report)
      assert shell.messages.empty?
    end
  end

  describe "#end_report_source" do
    it "does nothing by default" do
      reporter.end_report_source(source, report)
      assert shell.messages.empty?
    end
  end

  describe "#begin_report_dependency" do
    it "does nothing by default" do
      reporter.begin_report_dependency(dependency, report)
      assert shell.messages.empty?
    end
  end

  describe "#end_report_dependency" do
    it "does nothing by default" do
      reporter.begin_report_dependency(dependency, report)
      assert shell.messages.empty?
    end
  end
end
