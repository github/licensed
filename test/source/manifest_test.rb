# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Source::Manifest do
  let(:fixtures) { File.expand_path("../../fixtures/manifest", __FILE__) }
  let(:config) { Licensed::Configuration.new("cache_path" => fixtures) }
  let(:source) { Licensed::Source::Manifest.new(config) }

  describe "enabled?" do
    it "is true if manifest.json exists in license directory" do
      assert source.enabled?
    end

    it "is false if manifest.json does not exist in license directory" do
      config["cache_path"] = Dir.tmpdir
      refute source.enabled?
    end
  end

  describe "dependencies" do
    it "includes dependencies from the manifest" do
      dep = source.dependencies.detect { |d| d["name"] == "manifest_test" }
      assert dep
      assert_equal "manifest", dep["type"]
      assert dep["version"] # version comes from git, just make sure its there
    end

    describe "paths" do
      it "finds the common folder path for the dependency" do
        dep = source.dependencies.detect { |d| d["name"] == "manifest_test" }
        assert_equal fixtures, dep.path
      end

      it "uses the first source if there is no common path" do
        dep = source.dependencies.detect { |d| d["name"] == "other" }
        assert dep.path.end_with?("script/console")
      end
    end
  end

  describe "manifest" do
    it "loads json" do
      manifest_path = File.join(fixtures, "manifest.json")
      config["manifest"] = { "path" => manifest_path }

      assert source.manifest && !source.manifest.empty?
    end

    it "loads yaml" do
      manifest_path = File.join(fixtures, "manifest.yml")
      config["manifest"] = { "path" => manifest_path }

      assert source.manifest && !source.manifest.empty?
    end
  end

  describe "manifest_path" do
    it "defaults to cache_path/manifest.json" do
      assert_equal Pathname.new(fixtures).join("manifest.json"),
                   source.manifest_path
    end

    it "can be set in configuration" do
      config["cache_path"] = Dir.tmpdir

      manifest_path = File.join(fixtures, "manifest.json")
      config["manifest"] = { "path" => manifest_path }

      assert_equal Pathname.new(manifest_path), source.manifest_path
    end
  end
end
