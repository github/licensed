# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Source::Manifest do
  let(:fixtures) { File.expand_path("../../fixtures/manifest", __FILE__) }
  let(:config) { Licensed::Configuration.new("cache_path" => fixtures) }
  let(:source) { Licensed::Source::Manifest.new(config) }

  describe "enabled?" do
    it "is true if manifest file exists" do
      # test uses the default manifest file path <cache path>/manifest.json
      assert source.enabled?
    end

    it "is true if dependencies are configured" do
      config["cache_path"] = Dir.tmpdir
      config["manifest"] = {
        "dependencies" => {
          "manifest_test" => "**/*"
        }
      }
      assert source.enabled?
    end

    it "is false if manifest file does not exist and dependencies are not configured" do
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

    it "uses a license specified in the configuration if provided" do
      config["manifest"] = {
        "licenses" => {
          "manifest_test" => "test/fixtures/manifest/with_license_file/LICENSE"
        }
      }

      dep = source.dependencies.detect { |d| d["name"] == "manifest_test" }
      assert dep
      dep.detect_license!
      assert_equal "mit", dep["license"]

      license_path = File.join(Licensed::Git.repository_root, config.dig("manifest", "licenses", "manifest_test"))
      assert_equal File.read(license_path).strip, dep.text
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
    describe "from a manifest file" do
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

    describe "from a generated manifest" do
      let(:manifest_config) do
        {
          # exclude all files that aren't in the generated manifest test folder
          "exclude" => [
            "**/*",
            "!test/fixtures/manifest/generated_manifest/**/*"
          ]
        }
      end
      let(:config) { Licensed::Configuration.new("manifest" => manifest_config) }

      it "excludes files matching patterns in the \"exclude\" setting" do
        config["manifest"]["dependencies"] = {
          "manifest_test" => "**/*"
        }
        manifest = source.manifest
        assert manifest.all? { |file, _| file.include?("test/fixtures/manifest/generated_manifest") }
      end

      it "matches files to dependencies using glob patterns" do
        config["manifest"]["dependencies"] = {
          "manifest_test" => ["**/*", "!**/nested/*"],
          "nested" => "**/nested/*"
        }

        source.manifest.each do |file, dependency|
          if file.include?("nested")
            assert_equal "nested", dependency
          else
            assert_equal "manifest_test", dependency
          end
        end
      end

      it "raises an error if the \"dependencies\" setting is empty" do
        config["manifest"]["dependencies"] = {}

        err = assert_raises RuntimeError do
          source.manifest
        end

        assert err.message.include?("\"dependencies\" cannot be empty")
      end

      it "raises an error if any files match multiple dependencies" do
        config["manifest"]["dependencies"] = {
          "manifest_test" => "**/*",
          "manifest_test_2" => "**/*"
        }

        err = assert_raises RuntimeError do
          source.manifest
        end
        assert err.message.include?("matched multiple configured dependencies: manifest_test, manifest_test_2")
      end

      it "raises an error if any files do not match any dependencies" do
        config["manifest"]["dependencies"] = {
          "manifest_test" => "!**/nested/*"
        }

        err = assert_raises RuntimeError do
          source.manifest
        end
        assert err.message.include?("nested.c did not match a configured dependency")
      end
    end
  end

  describe "generate_manifest?" do
    it "is false when a manifest file exists" do
      # test uses the default manifest file path <cache_path>/manifest.json
      refute source.generate_manifest?
    end

    it "is false when manifest dependencies are not configured" do
      config["cache_path"] = Dir.tmpdir
      config["manifest"] = {}
      refute source.generate_manifest?
    end

    it "is true when a manifest file does not exist and dependencies are configured" do
      config["cache_path"] = Dir.tmpdir
      config["manifest"] = {
        "dependencies" => {
          "manifest_test" => "**/*"
        }
      }

      assert source.generate_manifest?
    end
  end

  describe "files_from_pattern_list" do
    it "returns an empty set if the patterns argument is nil or empty" do
      assert_equal Set.new, source.files_from_pattern_list(nil)
      assert_equal Set.new, source.files_from_pattern_list([])
      assert_equal Set.new, source.files_from_pattern_list("")
    end

    it "finds files for a single pattern" do
      files = source.files_from_pattern_list(["lib/**/*.rb"])
      assert files.include?("lib/licensed/source/manifest.rb")
      assert files.include?("lib/licensed/command/list.rb")
      refute files.include?("test/command/cache_test.rb")
    end

    it "finds files for an array of patterns" do
      files = source.files_from_pattern_list(["lib/**/manifest.rb", "lib/**/list.rb"])
      assert files.include?("lib/licensed/source/manifest.rb")
      assert files.include?("lib/licensed/command/list.rb")
    end

    it "finds files for a directory pattern" do
      files = source.files_from_pattern_list(["lib/**/source/*"])
      assert files.include?("lib/licensed/source/manifest.rb")
      assert files.include?("lib/licensed/source/bundler.rb")
    end

    it "understands exclusion patterns" do
      files = source.files_from_pattern_list(["lib/**/source/*", "!**/manifest.rb"])
      refute files.include?("lib/licensed/source/manifest.rb")
    end

    it "finds filenames starting with \".\"" do
      files = source.files_from_pattern_list("*")
      assert files.include?(".gitignore")
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
