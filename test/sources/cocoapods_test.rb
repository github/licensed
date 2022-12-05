# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("pod")
  describe Licensed::Sources::Cocoapods do
    let(:fixtures) { File.expand_path("../../fixtures/cocoapods", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:source) { Licensed::Sources::Cocoapods.new(config) }

    describe "enabled?" do
      it "is true if Podfiles exist" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if Podfiles do not exist" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "finds Cocoapods dependencies" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d.name == "Alamofire" }
          assert dep
          assert_equal "5.4.3", dep.version
        end
      end

      it "handle multiple subspecs from the same root dependencies" do
        Dir.chdir fixtures do
          assert source.dependencies.detect { |dep| dep.name == "MaterialComponents/Cards" }
          assert source.dependencies.detect { |dep| dep.name == "MaterialComponents/Buttons" }
        end
      end

      it "supports pods from git" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "Chatto" }
        end
      end

      it "it adds metadata when available" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "Alamofire" }
          assert dep.record["homepage"] != nil
          assert dep.record["summary"] != nil
        end
      end
    end

    describe "targets" do
      it "includes only dependencies from target if configured" do
        Dir.chdir fixtures do
          config["cocoapods"] = { "targets" => ["iosTests"] }
          assert source.dependencies.detect { |dep| dep.name == "lottie-ios" }
          assert_nil source.dependencies.detect { |dep| dep.name == "Alamofire" }
        end
      end
    end
  end
end
