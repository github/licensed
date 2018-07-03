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

      it "uses the first source folder if there is no common path" do
        dep = source.dependencies.detect { |d| d["name"] == "other" }
        assert dep.path.end_with?("script")
      end
    end

    it "prefers licenses from license files" do
      dep = source.dependencies.detect { |d| d["name"] == "mit_license_file" }
      assert dep
      dep.detect_license!
      assert_equal "mit", dep["license"]
      refute_nil dep.text
    end

    it "detects license from source header comments if license files are not found" do
      dep = source.dependencies.detect { |d| d["name"] == "bsd3_single_header_license" }
      assert dep
      dep.detect_license!
      assert_equal "bsd-3-clause", dep["license"]
      refute_nil dep.text
      refute dep.text.include?(Licensed::License::LICENSE_SEPARATOR)

      # verify that the license file was removed after evaluation
      refute File.exist?(File.join(dep.path, "LICENSE"))
    end

    it "detects unique license content from multiple headers" do
      dep = source.dependencies.detect { |d| d["name"] == "bsd3_multi_header_license" }
      assert dep
      dep.detect_license!
      # because there are different licenses/copyrights that need to be included
      # we aren't able to specify that the actual license content is equivalent
      # so we are left with "other"
      assert_equal "other", dep["license"]
      refute_nil dep.text
      assert dep.text.include?(Licensed::License::LICENSE_SEPARATOR)
    end

    it "preserves legal notices when detecting license content from comments" do
      dep = source.dependencies.detect { |d| d["name"] == "notices" }
      assert dep
      dep.detect_license!
      refute_nil dep.text
      assert dep.text.include?(dep.notices.join("\n#{Licensed::License::TEXT_SEPARATOR}\n").strip)
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
