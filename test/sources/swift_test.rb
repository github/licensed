# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("swift")
  describe Licensed::Sources::Swift do
    let(:fixtures) { File.expand_path("../../fixtures/swift", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:source) { Licensed::Sources::Swift.new(config) }

    describe "enabled?" do
      it "is true if Swift package exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if Swift package doesn't exist" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "enumerate_dependencies" do
      it "does not include the source project" do
        Dir.chdir(fixtures) do
          config["name"] = "Fixtures"
          refute source.enumerate_dependencies.find { |d| d.name == "Fixtures" }
        end
      end

      it "finds dependencies from path sources" do
        Dir.chdir(fixtures) do
          dep = source.enumerate_dependencies.find { |d| d.name == "LinkedList" }
          assert dep
          assert_equal "1.2.1", dep.version
          assert_equal "https://github.com/mona/LinkedList.git", dep.url

          dep = source.enumerate_dependencies.find { |d| d.name == "Invalid" }
          refute dep
        end
      end
    end
  end
end
