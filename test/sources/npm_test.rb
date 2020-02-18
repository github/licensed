# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("npm")
  describe Licensed::Sources::NPM do
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }
    let(:source) { Licensed::Sources::NPM.new(config) }

    describe "enabled?" do
      it "is true if package.json exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "package.json", ""
            assert source.enabled?
          end
        end
      end

      it "is false no npm configs exist" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "includes declared dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "autoprefixer" }
          assert dep
          assert_equal "npm", dep.record["type"]
          assert_equal "5.2.0", dep.version
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "handles scoped dependency names" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "@github/query-selector" }
          assert dep
          assert_equal "1.0.3", dep.version
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "includes indirect dependencies" do
        Dir.chdir fixtures do
          assert source.dependencies.detect { |dep| dep.name == "autoprefixer" }
        end
      end

      it "does not include dev dependencies by default" do
        Dir.chdir fixtures do
          refute source.dependencies.detect { |dep| dep.name == "string.prototype.startswith" }
        end
      end

      it "includes dev dependencies if configured" do
        Dir.chdir fixtures do
          config["npm"] = { "production_only" => false }
          assert source.dependencies.detect { |dep| dep.name == "string.prototype.startswith" }
        end
      end

      it "does not include ignored dependencies" do
        Dir.chdir fixtures do
          config.ignore({ "type" => Licensed::Sources::NPM.type, "name" => "autoprefixer" })
          refute source.dependencies.detect { |dep| dep.name == "autoprefixer" }
        end
      end

      describe "with multiple instances of a dependency" do
        it "includes version in the dependency name for multiple unique versions" do
          Dir.chdir fixtures do
            graceful_fs_dependencies = source.dependencies.select { |dep| dep.name == "graceful-fs" }
            assert_empty graceful_fs_dependencies

            graceful_fs_dependencies = source.dependencies.select { |dep| dep.name =~ /graceful-fs/ }
            assert_equal 2, graceful_fs_dependencies.size
            graceful_fs_dependencies.each do |dependency|
              assert_equal "#{dependency.record["name"]}-#{dependency.version}", dependency.name
            end
          end
        end

        it "does not include version in the dependency name for a single unique version" do
          Dir.chdir fixtures do
            dep = source.dependencies.detect { |d| d.name == "wrappy" }
            assert_equal "wrappy", dep.name
          end
        end
      end
    end

    describe "missing dependencies (glob is missing package)" do
      it "includes missing dependencies when yarn.lock is missing" do
        Dir.mktmpdir do |dir|
          FileUtils.cp_r(fixtures, dir)
          dir = File.join(dir, "npm")
          FileUtils.rm_rf(File.join(dir, "node_modules/glob"))

          Dir.chdir dir do
            assert source.dependencies.detect { |dep| dep.name == "autoprefixer" }
            assert source.dependencies.detect { |dep| dep.name == "glob" }
          end
        end
      end

      it "excludes missing dependencies when yarn.lock is present" do
        Dir.mktmpdir do |dir|
          FileUtils.cp_r(fixtures, dir)
          dir = File.join(dir, "npm")
          FileUtils.rm_rf(File.join(dir, "node_modules/glob"))
          File.write(File.join(dir, "yarn.lock"), "")

          Dir.chdir dir do
            assert source.dependencies.detect { |dep| dep.name == "autoprefixer" }
            refute source.dependencies.detect { |dep| dep.name == "glob" }
          end
        end
      end
    end
  end
end
