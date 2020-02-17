# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("pipenv")
  describe Licensed::Sources::Pipenv do
    let (:fixtures) { File.expand_path("../../fixtures/pipenv", __FILE__) }
    let (:config)   { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let (:source)   { Licensed::Sources::Pipenv.new(config) }

    describe "enabled?" do
      it "is true if pipenv source is available" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if pipenv source is not available" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "detects top-level dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "pylint" }
          assert dep
          assert_equal "pipenv", dep.record["type"]
          assert_equal "2.3.1", dep.version
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "detects nested dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "isort" }
          assert dep
          assert_equal "pipenv", dep.record["type"]
          # pylint requires isort <5,>=4.2.5
          assert Gem::Requirement.new("<5", ">=4.2.5").satisfied_by?(Gem::Version.new(dep.version))
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "detects dependencies with hyphens in package name" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "lazy-object-proxy" }
          assert dep
          assert_equal "pipenv", dep.record["type"]
          assert dep.version
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end
    end
  end
end
