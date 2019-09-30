# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("mix")
  describe Licensed::Sources::Mix do
    let(:fixtures) { File.expand_path("../../fixtures/mix", __FILE__) }
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Sources::Mix.new(config) }

    describe "enabled?" do
      it "is true if mix.lock exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if no mix.lock exists" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "dependencies" do
      it "finds indirect dependencies" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "mime" }
          path = File.absolute_path(File.join(".", "deps", "mime"))
          assert dep
          assert_equal path, dep.path
          assert_equal "1.3.1", dep.version
          assert_equal "hex", dep.record["type"]
          assert_equal "hexpm", dep.record["repo"]
        end
      end

      it "finds direct dependencies" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "phoenix" }
          path = File.absolute_path(File.join(".", "deps", "phoenix"))
          assert dep
          assert_equal path, dep.path
          assert_equal "1.4.10", dep.version
          assert_equal "hex", dep.record["type"]
          assert_equal "hexpm", dep.record["repo"]
        end
      end
    end
  end
end
