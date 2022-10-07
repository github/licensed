# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("pip")
  describe Licensed::Sources::Pip do
    let (:fixtures)  { File.expand_path("../../fixtures/pip", __FILE__) }
    let (:config)   { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd, "python" => {"virtual_env_dir" => "test/fixtures/pip/venv" } }) }
    let (:source)   { Licensed::Sources::Pip.new(config) }

    describe "enabled?" do
      it "is true if pip source is available" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if pip source is not available" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "detects explicit dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Jinja2" }
          assert dep
          assert_equal "3.0.0", dep.version
          assert_equal "pip", dep.record["type"]
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "detects transitive dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "MarkupSafe" }
          assert dep
          assert_equal "pip", dep.record["type"]
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "finds license contents from .dist-info/license_files" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "datadog" }
          assert dep.path.end_with?("license_files")
          refute_empty dep.license_files
        end
      end

      it "finds hatch build backend license contents from .dist-info/licenses" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "nbconvert" }
          assert dep.path.end_with?("licenses")
          refute_empty dep.license_files
        end
      end
    end
  end
end
