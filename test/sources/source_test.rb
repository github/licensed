# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

describe Licensed::Sources::Source do
  let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:source) { TestSource.new(config) }

  describe "dependencies" do
    it "returns dependencies from the source" do
      dep = source.dependencies.first
      assert dep
      assert dep.name == "dependency"
    end

    it "does not return ignored dependencies" do
      config.ignore("type" => "test", "name" => "dependency")
      assert_empty source.dependencies
    end

    it "adds configured dependency amendments to dependencies" do
      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          config["amendments"] = {
            TestSource.type => {
              TestSource::DEFAULT_DEPENDENCY_NAME => "amendment.txt"
            }
          }
          File.write "amendment.txt", "amendment"
          dep = source.dependencies.first
          assert_equal [Pathname.pwd.join("amendment.txt")], dep.amendments
        end
      end
    end
  end
end
