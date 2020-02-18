# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Sources::Manifest do
  let(:fixtures) { File.expand_path("../../fixtures/manifest", __FILE__) }
  let(:source_config) { Hash.new }
  let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd, "cache_path" => fixtures, "manifest" => source_config }) }
  let(:source) { Licensed::Sources::Manifest.new(config) }

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
      dep = source.dependencies.detect { |d| d.name == "manifest_test" }
      assert dep
      assert_equal "manifest", dep.record["type"]
      assert dep.version # version comes from git, just make sure its there
    end

    it "uses a license specified in the configuration if provided" do
      config["manifest"] = {
        "licenses" => {
          "manifest_test" => "test/fixtures/manifest/with_license_file/LICENSE"
        }
      }

      dep = source.dependencies.detect { |d| d.name == "manifest_test" }
      assert dep
      assert_equal "mit", dep.record["license"]

      license_path = File.join(config.root, config.dig("manifest", "licenses", "manifest_test"))
      license = dep.record.licenses.find { |l| l.sources == ["LICENSE"] }
      assert license
      assert_equal File.read(license_path), license.text
    end

    it "prefers licenses from license files" do
      dep = source.dependencies.detect { |d| d.name == "mit_license_file" }
      assert dep
      assert_equal "mit", dep.record["license"]
      refute_empty dep.record.licenses
    end

    it "detects unique license content from redundant source header comments" do
      dep = source.dependencies.detect { |d| d.name == "bsd3_single_header_license" }
      assert dep
      assert_equal "bsd-3-clause", dep.record["license"]
      assert_equal 1, dep.record.licenses.size

      _, sources = source.packages.detect { |name, _| name == "bsd3_single_header_license" }
      assert_equal sources.map { |s| File.basename(s) },
                   dep.record.licenses.first.sources
    end

    it "detects unique license content from multiple headers" do
      dep = source.dependencies.detect { |d| d.name == "bsd3_multi_header_license" }
      assert dep
      assert_equal "bsd-3-clause", dep.record["license"]
      assert_equal 2, dep.record.licenses.size
    end

    it "preserves legal notices when detecting license content from comments" do
      dep = source.dependencies.detect { |d| d.name == "notices" }
      assert dep
      refute_empty dep.record.notices
    end

    it "uses the git commit SHA as the version if configured" do
      config["version_strategy"] = Licensed::Sources::ContentVersioning::GIT
      dep = source.dependencies.detect { |d| d.name == "version_test" }
      assert_equal source.git_version(source.packages["version_test"]), dep.version
    end

    it "uses the git commit SHA as the version if not configured" do
      dep = source.dependencies.detect { |d| d.name == "version_test" }
      assert_equal source.git_version(source.packages["version_test"]), dep.version
    end

    it "uses the file contents hash as the version if configured" do
      config["version_strategy"] = Licensed::Sources::ContentVersioning::CONTENTS
      dep = source.dependencies.detect { |d| d.name == "version_test" }
      assert_equal source.contents_hash(source.packages["version_test"]), dep.version
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
      let(:fixtures) { File.expand_path("../../fixtures/manifest/generated_manifest", __FILE__) }
      let(:source_config) do
        {
          # exclude all files that aren't in the generated manifest test folder
          "exclude" => [
            "**/*",
            "!test/fixtures/manifest/generated_manifest/**/*"
          ]
        }
      end

      it "excludes files matching patterns in the \"exclude\" setting" do
        source_config["dependencies"] = {
          "manifest_test" => "**/*"
        }
        manifest = source.manifest
        assert manifest.all? { |file, _| file.include?("test/fixtures/manifest/generated_manifest") }
      end

      it "matches files to dependencies using glob patterns" do
        source_config["dependencies"] = {
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
        source_config["dependencies"] = {}

        err = assert_raises Licensed::Sources::Source::Error do
          source.manifest
        end

        assert err.message.include?("\"dependencies\" cannot be empty")
      end

      it "raises an error if any files match multiple dependencies" do
        source_config["dependencies"] = {
          "manifest_test" => "**/*",
          "manifest_test_2" => "**/*"
        }

        err = assert_raises Licensed::Sources::Source::Error do
          source.manifest
        end
        assert err.message.include?("matched multiple configured dependencies: manifest_test, manifest_test_2")
      end

      it "raises an error if any files do not match any dependencies" do
        source_config["dependencies"] = {
          "manifest_test" => "!**/nested/*"
        }

        err = assert_raises Licensed::Sources::Source::Error do
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
      assert files.include?("lib/licensed/sources/manifest.rb")
      assert files.include?("lib/licensed/commands/list.rb")
      refute files.include?("test/commands/cache_test.rb")
    end

    it "finds files for an array of patterns" do
      files = source.files_from_pattern_list(["lib/**/manifest.rb", "lib/**/list.rb"])
      assert files.include?("lib/licensed/sources/manifest.rb")
      assert files.include?("lib/licensed/commands/list.rb")
    end

    it "finds files for a directory pattern" do
      files = source.files_from_pattern_list(["lib/**/sources/*"])
      assert files.include?("lib/licensed/sources/manifest.rb")
      assert files.include?("lib/licensed/sources/bundler.rb")
    end

    it "understands exclusion patterns" do
      files = source.files_from_pattern_list(["lib/**/sources/*", "!**/manifest.rb"])
      refute files.include?("lib/licensed/sources/manifest.rb")
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
