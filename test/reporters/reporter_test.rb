# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::Reporter do
  let(:reporter) { Licensed::Reporters::Reporter.new }
  let(:app) { { "name" => "app" } }
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new(config) }
  let(:dependency) { source.dependencies.first }

  describe "#report_run" do
    it "runs a block" do
      success = false
      reporter.report_run { success = true }
      assert success
    end

    it "returns the result of the block" do
      assert_equal 1, reporter.report_run { 1 }
    end

    it "provides a report hash to the block" do
      reporter.report_run { |report| refute_nil report }
    end
  end

  describe "#report_app" do
    it "runs a block" do
      success = false
      reporter.report_run do
        reporter.report_app(app) { success = true }
      end
      assert success
    end

    it "returns the result of the block" do
      reporter.report_run do
        assert_equal 1, reporter.report_app(app) { 1 }
      end
    end

    it "provides a report hash to the block" do
      reporter.report_run do
        reporter.report_app(app) { |report| refute_nil report }
      end
    end

    it "stores the app report to the run report" do
      reporter.report_run do |run_report|
        reporter.report_app(app) do |app_report|
          app_report["success"] = true
        end

        assert run_report[app["name"]]["success"]
      end
    end

    it "raises an error for recursive calls" do
      reporter.report_run do
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
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) { success = true }
        end
      end

      assert success
    end

    it "returns the result of the block" do
      reporter.report_run do
        reporter.report_app(app) do
          assert_equal 1, reporter.report_source(source) { 1 }
        end
      end
    end

    it "provides a report hash to the block" do
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) { |report| refute_nil report }
        end
      end
    end

    it "stores the source report to the app report" do
      reporter.report_run do
        reporter.report_app(app) do |app_report|
          reporter.report_source(source) do |source_report|
            source_report["success"] = true
          end

          assert app_report[source.class.type]["success"]
        end
      end
    end

    it "raises an error for recursive calls" do
      reporter.report_run do
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
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { success = true }
          end
        end
      end

      assert success
    end

    it "returns the result of the block" do
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) do
            assert_equal 1, reporter.report_dependency(dependency) { 1 }
          end
        end
      end
    end

    it "provides a report hash to the block" do
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| refute_nil report }
          end
        end
      end
    end

    it "stores the dependency report to the source report" do
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) do |source_report|
            reporter.report_dependency(dependency) do |dependency_report|
              dependency_report["success"] = true
            end

            assert source_report[dependency.name]["success"]
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
