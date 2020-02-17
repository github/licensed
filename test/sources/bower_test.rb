# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("bower")
  describe Licensed::Sources::Bower do
    let(:fixtures) { File.expand_path("../../fixtures/bower", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:source) { Licensed::Sources::Bower.new(config) }

    describe "enabled?" do
      it "is true if .bowerrc exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write ".bowerrc", ""
            assert source.enabled?
          end
        end
      end

      it "is true if bower.json exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false no bower configs exist" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "dependencies" do
      it "finds bower dependencies" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d.name == "jquery" }
          assert dep
          assert_equal "2.1.4", dep.version
        end
      end
    end
  end
end
