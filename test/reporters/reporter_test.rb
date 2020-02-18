# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::Reporter do
  let(:reporter) { Licensed::Reporters::Reporter.new }
  let(:app) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:source) { TestSource.new(app) }
  let(:dependency) { source.dependencies.first }
  let(:command) { TestCommand.new(config: nil, reporter: reporter) }

  describe "#report_run" do
    it "runs a block" do
      success = false
      reporter.report_run(command) { success = true }
      assert success
    end

    it "returns the result of the block" do
      assert_equal 1, reporter.report_run(command) { 1 }
    end

    it "provides a report to the block" do
      reporter.report_run(command) do |report|
        assert report.is_a?(Licensed::Reporters::Reporter::Report)
        assert_equal command, report.target
        assert_nil report.name
      end
    end
  end

  describe "#report_app" do
    it "runs a block" do
      success = false
      reporter.report_run(command) do
        reporter.report_app(app) { success = true }
      end
      assert success
    end

    it "returns the result of the block" do
      reporter.report_run(command) do
        assert_equal 1, reporter.report_app(app) { 1 }
      end
    end

    it "provides a report to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do |report|
          assert report.is_a?(Licensed::Reporters::Reporter::Report)
          assert_equal app, report.target
          assert_equal app["name"], report.name
        end
      end
    end

    it "stores the app report to the run report" do
      reporter.report_run(command) do |run_report|
        reporter.report_app(app) {}
        assert run_report.reports.find { |report| report.target == app }
      end
    end

    it "raises an error for recursive calls" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          assert_raises Licensed::Reporters::Reporter::ReportingError do
            reporter.report_app(app) {}
          end
        end
      end
    end

    it "raises an error if called outside of run_report" do
      assert_raises Licensed::Reporters::Reporter::ReportingError do
        reporter.report_app(app) {}
      end
    end
  end

  describe "#report_source" do
    it "runs a block" do
      success = false
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) { success = true }
        end
      end

      assert success
    end

    it "returns the result of the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          assert_equal 1, reporter.report_source(source) { 1 }
        end
      end
    end

    it "provides a report to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do |report|
            assert report.is_a?(Licensed::Reporters::Reporter::Report)
            assert_equal source, report.target
            assert_equal "#{app["name"]}.#{source.class.type}", report.name
          end
        end
      end
    end

    it "stores the source report to the app report" do
      reporter.report_run(command) do
        reporter.report_app(app) do |app_report|
          reporter.report_source(source) {}
          assert app_report.reports.find { |report| report.target == source }

        end
      end
    end

    it "raises an error for recursive calls" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            assert_raises Licensed::Reporters::Reporter::ReportingError do
              reporter.report_source(source) {}
            end
          end
        end
      end
    end

    it "raises an error if called outside of report_app" do
      assert_raises Licensed::Reporters::Reporter::ReportingError do
        reporter.report_source(source) {}
      end
    end
  end

  describe "#report_dependency" do
    it "runs a block" do
      success = false
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { success = true }
          end
        end
      end

      assert success
    end

    it "returns the result of the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            assert_equal 1, reporter.report_dependency(dependency) { 1 }
          end
        end
      end
    end

    it "provides a report to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) do |report|
              assert report.is_a?(Licensed::Reporters::Reporter::Report)
              assert_equal dependency, report.target
              assert_equal "#{app["name"]}.#{source.class.type}.#{dependency.name}", report.name
            end
          end
        end
      end
    end

    it "stores the dependency report to the source report" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do |source_report|
            reporter.report_dependency(dependency) {}
            assert source_report.reports.find { |report| report.target == dependency }
          end
        end
      end
    end

    it "raises an error if called outside of report_source" do
      assert_raises Licensed::Reporters::Reporter::ReportingError do
        reporter.report_dependency(dependency) {}
      end
    end
  end
end

describe Licensed::Reporters::Reporter::Report do
  let(:report) { Licensed::Reporters::Reporter::Report.new(name: "test", target: nil) }

  describe "#to_h" do
    it "includes hash data" do
      report[:key1] = "value1"
      report["key2"] = "value2"

      output = report.to_h
      assert_equal "value1", output[:key1]
      assert_equal "value2", output["key2"]
    end

    it "includes the report name if the name key isn't already set" do
      output = report.to_h
      assert_equal "test", output["name"]

      report["name"] = "test_updated"
      output = report.to_h
      assert_equal "test_updated", output["name"]
    end

    it "includes warnings when set" do
      output = report.to_h
      assert_nil output["warnings"]

      report.warnings << "warning"
      output = report.to_h
      assert_equal ["warning"], output["warnings"]
    end

    it "includes errors when set" do
      output = report.to_h
      assert_nil output["errors"]

      report.errors << "error"
      output = report.to_h
      assert_equal ["error"], output["errors"]
    end
  end
end
