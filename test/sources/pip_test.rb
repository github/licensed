# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("pip")
  describe Licensed::Sources::Pip do
    let (:fixtures)  { File.expand_path("../../fixtures/pip", __FILE__) }
    let (:config)   { Licensed::Configuration.new("python" => {"virtual_env_dir" => "test/fixtures/pip/venv"}) }
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
      it "includes direct dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Jinja2" }
          assert dep
          assert_equal "pip", dep.data["type"]
          assert dep.data["homepage"]
          assert dep.data["summary"]
        end
      end

      it "includes indirect dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "MarkupSafe" }
          assert dep
          assert_equal "pip", dep.data["type"]
          assert dep.data["homepage"]
          assert dep.data["summary"]
        end
      end
    end
  end
end
