# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("yarn")
  describe Licensed::Sources::Yarn do
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:fixtures) { File.expand_path("../../fixtures/yarn", __FILE__) }
    let(:source) { Licensed::Sources::Yarn.new(config) }

    describe "enabled?" do
      it "is true if package.json and yarn.lock exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "package.json", ""
            File.write "yarn.lock", ""
            assert source.enabled?
          end
        end
      end

      it "is false if package.json does not exist" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "yarn.lock", ""
            refute source.enabled?
          end
        end
      end

      it "is false if yarn.lock does not exist" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "package.json", ""
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
          assert_equal "yarn", dep.record["type"]
          assert_equal "5.2.0", dep.version
          assert dep.record["homepage"]
        end
      end

      it "handles scoped dependency names" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "@github/query-selector" }
          assert dep
          assert_equal "1.0.3", dep.version
          assert dep.record["homepage"]
        end
      end

      it "includes indirect dependencies" do
        Dir.chdir fixtures do
          assert source.dependencies.detect { |dep| dep.name == "autoprefixer-core" }
        end
      end

      it "does not include dev dependencies by default" do
        Dir.chdir fixtures do
          refute source.dependencies.detect { |dep| dep.name == "string.prototype.startswith" }
        end
      end

      it "includes dev dependencies if configured" do
        Dir.chdir fixtures do
          config["yarn"] = { "production_only" => false }
          assert source.dependencies.detect { |dep| dep.name == "string.prototype.startswith" }
        end
      end

      it "does not include ignored dependencies" do
        Dir.chdir fixtures do
          config.ignore({ "type" => Licensed::Sources::Yarn.type, "name" => "autoprefixer" })
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
              assert dependency.exist?
            end
          end
        end

        it "does not include version in the dependency name for a single unique version" do
          Dir.chdir fixtures do
            dep = source.dependencies.detect { |d| d.name == "wrappy" }
            assert dep
            assert_equal "wrappy", dep.name
          end
        end
      end
    end

    describe "packages" do
      it "returns an empty list if no packages are found" do
        Dir.mktmpdir do |dir|
          Dir.chdir dir do
            assert_empty source.packages
          end
        end
      end
    end
  end
end
