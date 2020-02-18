# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::StatusReporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::StatusReporter.new(shell) }
  let(:app) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:source) { TestSource.new(app) }
  let(:dependency) { source.dependencies.first }
  let(:command) { TestCommand.new(config: nil, reporter: reporter) }

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

    it "provides a report hash to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) { |report| refute_nil report }
      end
    end

    it "prints messages about app to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) do |report|
              report["meta1"] = "data1"
              report["meta2"] = "data2"
              report.errors << "error1"
              report.errors << "error2"
            end
          end
        end

        assert_includes shell.messages,
                        {
                           message: "Checking cached dependency records for #{app["name"]}",
                           newline: true,
                           style: :info
                        }

        assert_includes shell.messages,
                        {
                           message: "* #{app["name"]}.#{source.class.type}.#{dependency.name}",
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

        assert_includes shell.messages,
                        {
                           message: "1 dependencies checked, 2 errors found.",
                           newline: true,
                           style: :info
                        }
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

    it "provides a report hash to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| refute_nil report }
          end
        end
      end
    end

    it "prints an 'F' error if result has errors" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| report.errors << "error" }
            assert_includes shell.messages,
                            {
                               message: "F",
                               newline: false,
                               style: :error
                            }
          end
        end
      end
    end

    it "prints an '.' success if result does not have errors" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) {}
            assert_includes shell.messages,
                            {
                               message: ".",
                               newline: false,
                               style: :confirm
                            }
          end
        end
      end
    end
  end
end
