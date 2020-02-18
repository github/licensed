# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::CacheReporter do
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::CacheReporter.new(shell) }
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

    it "prints an informative message to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) {}

        assert_includes shell.messages,
                        {
                           message: "Caching dependency records for #{app["name"]}",
                           newline: true,
                           style: :info
                        }
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

    it "provides a report hash to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) { |report| refute_nil report }
        end
      end
    end

    it "prints informative messages to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) {}
          assert_includes shell.messages,
                          {
                             message: "  #{source.class.type}",
                             newline: true,
                             style: :info
                          }

          assert_includes shell.messages,
                          {
                             message: "  * 0 #{source.class.type} dependencies",
                             newline: true,
                             style: :confirm
                          }
        end
      end
    end

    it "reports warnings during the source run" do
      reporter.report_run(command) do
        reporter.report_app(app) do |app_report|
          reporter.report_source(source) do |source_report|
            reporter.report_dependency(dependency) do |dependency_report|
              dependency_report.warnings << "dependency warning"
            end
          end
        end

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
    end

    it "reports errors during the source run" do
      reporter.report_run(command) do
        reporter.report_app(app) do |app_report|
          reporter.report_source(source) do |source_report|
            source_report.errors << "source error"
            reporter.report_dependency(dependency) do |dependency_report|
              dependency_report.errors << "dependency error"
            end
          end
        end

        assert_includes shell.messages,
                        {

                           message: "      - source error",
                           newline: true,
                           style: :error
                        }
        assert_includes shell.messages,
                        {
                           message: "      - dependency error",
                           newline: true,
                           style: :error
                        }
        refute_includes shell.messages,
                        {
                           message: "  * 0 #{source.class.type} dependencies",
                           newline: true,
                           style: :confirm
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

    it "prints an informative messages for a cached dependency to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| report["cached"] = true }
            assert_includes shell.messages,
                            {
                               message: "    Caching #{dependency.name} (#{dependency.version})",
                               newline: true,
                               style: :info
                            }
          end
        end
      end
    end

    it "prints an informative messages for a skipped dependency to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| report["cached"] = false }
            assert_includes shell.messages,
                            {
                               message: "    Using #{dependency.name} (#{dependency.version})",
                               newline: true,
                               style: :info
                            }
          end
        end
      end
    end

    it "prints an informative messages for an errored dependency to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            reporter.report_dependency(dependency) { |report| report.errors << "error" }
            assert_includes shell.messages,
                            {
                               message: "    Error #{dependency.name} (#{dependency.version})",
                               newline: true,
                               style: :error
                            }
          end
        end
      end
    end
  end
end
