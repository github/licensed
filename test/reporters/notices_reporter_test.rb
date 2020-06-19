# frozen_string_literal: true
require "test_helper"

describe Licensed::Reporters::NoticesReporter do
  let(:cache_path) { Dir.mktmpdir }
  let(:shell) { TestShell.new }
  let(:reporter) { Licensed::Reporters::NoticesReporter.new(shell) }
  let(:app) { Licensed::AppConfiguration.new("source_path" => Dir.pwd, "cache_path" => cache_path) }
  let(:source) { TestSource.new(app) }
  let(:command) { TestCommand.new(config: nil, reporter: reporter) }

  after do
    FileUtils.rm_rf app.cache_path
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

    it "provides a report hash to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) { |report| refute_nil report }
      end
    end

    it "prints an informative message to the shell" do
      reporter.report_run(command) do
        reporter.report_app(app) {}

        path = app.cache_path.join("NOTICE")
        assert_includes shell.messages,
                        {
                           message: "Writing notices for #{app["name"]} to #{path}",
                           newline: true,
                           style: :info
                        }
      end
    end

    it "prints a warning if dependency notice contents can't be parsed" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              reporter.report_dependency(dependency) do |report|
                report["cached_record"] = Licensed::DependencyRecord.new(
                  licenses: [],
                  notices: [1]
                )
              end
            end
          end
        end
      end

      source.dependencies.each do |dependency|
        assert_includes shell.messages,
                        {
                           message: "* unable to parse notices for #{dependency.name}",
                           newline: true,
                           style: :warn
                        }
      end
    end

    it "writes dependencies' licenses and notices to a NOTICE file" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              reporter.report_dependency(dependency) do |report|
                report["cached_record"] = Licensed::DependencyRecord.new(
                  licenses: [
                    { "sources" => "LICENSE1", "text" => "license1" },
                    { "sources" => "LICENSE2", "text" => "license2" }
                  ],
                  notices: [
                    "notice1",
                    { "sources" => "NOTICE", "text" => "notice2" }
                  ]
                )
              end
            end
          end
        end

        path = app.cache_path.join("NOTICE")
        assert File.exist?(path)
        notices_contents = File.read(path)
        assert_includes notices_contents, "license1"
        assert_includes notices_contents, "license2"
        assert_includes notices_contents, "notice1"
        assert_includes notices_contents, "notice2"
      end
    end

    it "writes dependencies' licenses and notices to a NOTICE.<app> file in a shared cache" do
      app["shared_cache"] = true

      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              reporter.report_dependency(dependency) do |report|
                report["cached_record"] = Licensed::DependencyRecord.new(
                  licenses: [
                    { "sources" => "LICENSE1", "text" => "license1" },
                    { "sources" => "LICENSE2", "text" => "license2" }
                  ],
                  notices: [
                    "notice1",
                    { "sources" => "NOTICE", "text" => "notice2" }
                  ]
                )
              end
            end
          end
        end

        path = app.cache_path.join("NOTICE.#{app["name"]}")
        assert File.exist?(path)
        notices_contents = File.read(path)
        assert_includes notices_contents, "license1"
        assert_includes notices_contents, "license2"
        assert_includes notices_contents, "notice1"
        assert_includes notices_contents, "notice2"
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

    it "prints a warning from a source report" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) { |report| report.warnings << "warning" }
          assert_includes shell.messages,
                          {
                            message: "* #{app["name"]}.#{source.class.type}: warning",
                            newline: true,
                            style: :warn
                          }
        end
      end
    end
  end

  describe "#report_dependency" do
    it "runs a block" do
      success = false
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              reporter.report_dependency(dependency) { success = true }
            end
          end
        end
      end

      assert success
    end

    it "returns the result of the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              assert_equal 1, reporter.report_dependency(dependency) { 1 }
            end
          end
        end
      end
    end

    it "provides a report hash to the block" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              reporter.report_dependency(dependency) { |report| refute_nil report }
            end
          end
        end
      end
    end

    it "prints a warning from a dependency report" do
      reporter.report_run(command) do
        reporter.report_app(app) do
          reporter.report_source(source) do
            source.dependencies.each do |dependency|
              reporter.report_dependency(dependency) { |report| report.warnings << "warning" }
              assert_includes shell.messages,
                              {
                                message: "* #{app["name"]}.#{source.class.type}.#{dependency.name}: warning",
                                newline: true,
                                style: :warn
                              }
            end
          end
        end
      end
    end
  end
end
