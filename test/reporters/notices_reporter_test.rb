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

        path = app.cache_path.join("NOTICES")
        assert_includes shell.messages,
                        {
                           message: "Writing notices for #{app["name"]} to #{path}",
                           newline: true,
                           style: :info
                        }
      end
    end

    it "writes dependencies' licenses and notices to a NOTICES file" do
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
                  notices: ["notice1", "notice2"]
                )
              end
            end
          end
        end

        path = app.cache_path.join("NOTICES")
        assert File.exist?(path)
        notices_contents = File.read(path)
        assert_includes notices_contents, "license1"
        assert_includes notices_contents, "license2"
        assert_includes notices_contents, "notice1"
        assert_includes notices_contents, "notice2"
      end
    end

    it "writes dependencies' licenses and notices to a NOTICES.<app> file in a shared cache" do
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
                  notices: ["notice1", "notice2"]
                )
              end
            end
          end
        end

        path = app.cache_path.join("NOTICES.#{app["name"]}")
        assert File.exist?(path)
        notices_contents = File.read(path)
        assert_includes notices_contents, "license1"
        assert_includes notices_contents, "license2"
        assert_includes notices_contents, "notice1"
        assert_includes notices_contents, "notice2"
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
              reporter.report_dependency(dependency) { |report| report["warning"] = "warning" }
              assert_includes shell.messages,
                              {
                                message: "* warning",
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
