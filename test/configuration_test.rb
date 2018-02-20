# frozen_string_literal: true
require "test_helper"

describe Licensed::Configuration do
  let(:config) { Licensed::Configuration.new }

  before do
    @package = {"type" => "rubygem", "name" => "bundler", "license" => "mit"}
  end

  it "accepts a license directory path option" do
    config["cache_path"] = "path"
    assert_equal Licensed::Git.repository_root.join("path"), config.cache_path
  end

  it "sets default values" do
    assert_equal Pathname.pwd, config.source_path
    assert_equal Licensed::Git.repository_root.join(".licenses"),
                 config.cache_path
    assert_equal File.basename(Dir.pwd), config["name"]
  end

  describe "load_from" do
    let(:fixtures) { File.expand_path("../fixtures/config", __FILE__) }

    it "loads a config from a relative directory path" do
      relative_path = Pathname.new(fixtures).relative_path_from(Pathname.pwd)
      config = Licensed::Configuration.load_from(relative_path)
      assert_equal "licensed-yml", config["name"]
    end

    it "loads a config from an absolute directory path" do
      config = Licensed::Configuration.load_from(fixtures)
      assert_equal "licensed-yml", config["name"]
    end

    it "loads a config from a relative file path" do
      file = File.join(fixtures, "config.yml")
      relative_path = Pathname.new(file).relative_path_from(Pathname.pwd)
      config = Licensed::Configuration.load_from(relative_path)
      assert_equal "config-yml", config["name"]
    end

    it "loads a config from an absolute file path" do
      file = File.join(fixtures, "config.yml")
      config = Licensed::Configuration.load_from(file)
      assert_equal "config-yml", config["name"]
    end

    it "loads json configurations" do
      file = File.join(fixtures, ".licensed.json")
      config = Licensed::Configuration.load_from(file)
      assert_equal "licensed-json", config["name"]
    end

    it "sets a default cache_path" do
      config = Licensed::Configuration.load_from(fixtures)
      assert_equal Pathname.pwd.join(".licenses"), config.cache_path
    end

    it "raises an error if a default config file is not found" do
      Dir.mktmpdir do |dir|
        assert_raises ::Licensed::Configuration::LoadError do
          Licensed::Configuration.load_from(dir)
        end
      end
    end

    it "raises an error if the config file type is not understood" do
      file = File.join(fixtures, ".licensed.unknown")
      assert_raises ::Licensed::Configuration::LoadError do
        Licensed::Configuration.load_from(file)
      end
    end
  end

  describe "ignore" do
    it "marks the dependency as ignored" do
      refute config.ignored?(@package)
      config.ignore @package
      assert config.ignored?(@package)
    end
  end

  describe "review" do
    it "marks the dependency as reviewed" do
      refute config.reviewed?(@package)
      config.review @package
      assert config.reviewed?(@package)
    end
  end

  describe "allow" do
    it "marks the license as allowed" do
      refute config.allowed?(@package)
      config.allow "mit"
      assert config.allowed?(@package)
    end
  end

  describe "enabled?" do
    it "defaults to true for unconfigured source" do
      assert config.enabled?("npm")
    end

    it "is false if enabled in config" do
      config["sources"]["npm"] = true
      assert config.enabled?("npm")
    end

    it "is false if disable in config" do
      config["sources"]["npm"] = false
      refute config.enabled?("npm")
    end
  end

  describe "apps" do
    it "defaults to returning itself" do
      assert_equal [config], config.apps
    end

    describe "from configuration options" do
      let(:apps) do
        [
          {
            "name" => "app1",
            "override" => "override",
            "cache_path" => "app1/vendor/licenses",
            "source_path" => File.expand_path("../../", __FILE__)
          },
          {
            "name" => "app2",
            "cache_path" => "app2/vendor/licenses",
            "source_path" => File.expand_path("../../", __FILE__)
          }
        ]
      end
      let(:config) do
        Licensed::Configuration.new("apps" => apps,
                                    "override" => "default",
                                    "default" => "default")
      end

      it "returns apps from configuration" do
        assert_equal 2, config.apps.size
        assert_equal "app1", config.apps[0]["name"]
        assert_equal "app2", config.apps[1]["name"]
      end

      it "includes default options" do
        assert_equal "default", config.apps[0]["default"]
        assert_equal "default", config.apps[1]["default"]
      end

      it "overrides default options" do
        assert_equal "default", config["override"]
        assert_equal "override", config.apps[0]["override"]
      end

      it "uses a default name" do
        apps[0].delete("name")
        assert_equal "licensed", config.apps[0]["name"]
      end

      it "uses a default cache path" do
        apps[0].delete("cache_path")
        assert_equal Licensed::Git.repository_root.join(".licenses/app1"),
                     config.apps[0].cache_path
      end

      it "appends the app name to an inherited cache path" do
        apps[0].delete("cache_path")
        config = Licensed::Configuration.new("apps" => apps,
                                             "cache_path" => "vendor/cache")
        assert_equal Licensed::Git.repository_root.join("vendor/cache/app1"),
                     config.apps[0].cache_path
      end

      it "does not append the app name to an explicit cache path" do
        refute config.apps[0].cache_path.to_s.end_with? config.apps[0]["name"]
      end

      it "raises an error if source_path is not set on an app" do
        apps[0].delete("source_path")
        assert_raises ::Licensed::Configuration::LoadError do
          Licensed::Configuration.new("apps" => apps)
        end
      end
    end
  end
end
