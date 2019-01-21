# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::ListReporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::ListReporter.new(shell) }
  let(:app) { { "name" => "app" } }
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new(config) }
  let(:dependency) { source.dependencies.first }

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

    it "prints an informative message to the shell" do
      reporter.report_run do
        reporter.report_app(app) {}

        assert_includes shell.messages,
                        {
                           message: "Dependencies for #{app["name"]}",
                           newline: true,
                           style: :info
                        }
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

    it "prints informative messages to the shell" do
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) {}
          assert_includes shell.messages,
                          {
                             message: "  #{source.class.type} dependencies:",
                             newline: true,
                             style: :info
                          }

          assert_includes shell.messages,
                          {
                             message: "  * 0 #{source.class.type} dependencies",
                             newline: true,
                             style: :info
                          }
        end
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

    it "prints an informative messages for a cached dependency to the shell" do
      reporter.report_run do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| report["cached"] = true }
            assert_includes shell.messages,
                            {
                               message: "    #{dependency.name} (#{dependency.version})",
                               newline: true,
                               style: :info
                            }
          end
        end
      end
    end
  end
end
