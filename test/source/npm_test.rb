# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("npm")
  describe Licensed::Source::NPM do
    before do
      @config = Licensed::Configuration.new
      @config.ui.level = "silent"
      @source = Licensed::Source::NPM.new(@config)
    end

    describe "enabled?" do
      it "is true if package.json exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "package.json", ""
            assert @source.enabled?
          end
        end
      end

      it "is false no npm configs exist" do
        Dir.chdir(Dir.tmpdir) do
          refute @source.enabled?
        end
      end
    end

    describe "dependencies" do
      let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }

      it "includes declared dependencies" do
        Dir.chdir fixtures do
          dep = @source.dependencies.detect { |d| d["name"] == "autoprefixer" }
          assert dep
          assert_equal "npm", dep["type"]
          assert_equal "5.2.0", dep["version"]
          assert dep["homepage"]
          assert dep["summary"]
        end
      end

      it "includes transient dependencies" do
        Dir.chdir fixtures do
          assert @source.dependencies.detect { |dep| dep["name"] == "autoprefixer" }
        end
      end

      it "does not include dev dependencies" do
        Dir.chdir fixtures do
          refute @source.dependencies.detect { |dep| dep["name"] == "string.prototype.startswith" }
        end
      end

      it "does not include ignored dependencies" do
        Dir.chdir fixtures do
          @config.ignore({ "type" => Licensed::Source::NPM.type, "name" => "autoprefixer" })
          refute @source.dependencies.detect { |dep| dep["name"] == "autoprefixer" }
        end
      end

      it "raises when dependencies are missing" do
        Dir.mktmpdir do |dir|
          FileUtils.cp(File.join(fixtures, "package.json"), File.join(dir, "package.json"))
          Dir.chdir(dir) do
            error = assert_raises(Licensed::Shell::Error) { @source.dependencies }
            assert_includes error.message, "command exited with status 1"
            assert_includes error.message, "npm ERR! missing: autoprefixer@"
          end
        end
      end

      describe "with multiple instances of a dependency" do
        it "includes version in the dependency path for multiple unique versions" do
          Dir.chdir fixtures do
            graceful_fs_dependencies = @source.dependencies.select { |dep| dep["name"] == "graceful-fs" }
            assert_equal 2, graceful_fs_dependencies.count
            graceful_fs_dependencies.each do |dependency|
              assert_equal "#{dependency["name"]}-#{dependency["version"]}", dependency.name
            end
          end
        end

        it "does not include version in the dependency path for a single unique version" do
          Dir.chdir fixtures do
            dep = @source.dependencies.detect { |dep| dep["name"] == "wrappy" }
            assert_equal "wrappy", dep.name
          end
        end
      end
    end
  end
end
