# frozen_string_literal: true
require "test_helper"
require "tmpdir"

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
    end
  end
end
