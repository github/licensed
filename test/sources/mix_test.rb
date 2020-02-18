# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("mix")
  describe Licensed::Sources::Mix do
    let(:fixtures) { File.expand_path("../../fixtures/mix", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
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
          # mime requirement from plug is `~> 1.0`
          assert Gem::Requirement.new("~> 1.0").satisfied_by?(Gem::Version.new(dep.version))
          assert_equal "mix", dep.record["type"]
          # Mix-specific values
          assert_equal "hex", dep.record["scm"]
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
          assert_equal "mix", dep.record["type"]
          # Mix-specific values
          assert_equal "hex", dep.record["scm"]
          assert_equal "hexpm", dep.record["repo"]
        end
      end
    end

    describe "Mix.SCM types" do
      it "supports packages from hex" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "phoenix" }
          # Mix-specific values
          assert_equal "hex", dep.record["scm"]
          assert_equal "hexpm", dep.record["repo"]
        end
      end

      it "supports packages from git" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "gen_stage" }
          # Mix-specific values
          assert_equal "git", dep.record["scm"]
          assert_equal "https://github.com/elixir-lang/gen_stage.git", dep.record["repo"]
        end
      end
    end

    describe "lockfile parser" do
      describe "with an invalid lockfile" do
        let(:lockfile) { %Q(%{\n"bad": {"entry"}\n}) }

        it "raises a Licensed::Sources::Source::Error" do
          assert_raises Licensed::Sources::Source::Error do
            parse_lockfile_contents(lockfile)
          end
        end
      end

      describe "with a valid hex line" do
        let(:lockfile) { %Q(%{\n"foo": {:hex, :foo, "1.2.3", "30ce04ab3175b6ad0bdce0035cba77bba68b813d523d1aac73d9781b4d193cf8", [:mix], [], "hexpm"},\n}) }

        it "returns an entry for a valid package" do
          expectation = [
            {
              name: "foo",
              version: "1.2.3",
              metadata: {"scm" => "hex", "repo" => "hexpm"}
            }
          ]
          assert_equal expectation, parse_lockfile_contents(lockfile)
        end
      end

      describe "with a invalid hex line" do
        let(:lockfile) { %Q(%{\n"absinthe": {:hex, 1, 2},\n}) }

        it "returns an entry for an invalid package" do
          expectation = [
            {
              name: "absinthe",
              version: nil,
              metadata: {"scm" => "hex"},
              error: "Could not extract data from mix.lock line: \"absinthe\": {:hex, 1, 2},\n"
            }
          ]
          assert_equal expectation, parse_lockfile_contents(lockfile)
        end
      end
    end

    # Utility to parse the contents of a lockfile.
    #
    # contents - The contents of the mix.lock as a String.
    #
    # Returns the result of Licensed::Sources::Mix::LockfileParser#result.
    def parse_lockfile_contents(contents)
      Licensed::Sources::Mix::LockfileParser.new(contents.lines).result
    end
  end
end
