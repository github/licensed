# frozen_string_literal: true
require "test_helper"

describe Licensed::Configuration do
  let(:options) { { } }
  let(:config) { Licensed::Configuration.new(options) }
  let(:fixtures) { File.expand_path("../fixtures/config", __FILE__) }

  describe "load_from" do
    let(:config) { Licensed::Configuration.load_from(load_path) }
    let(:app) { config.apps.first }

    describe "a relative directory path" do
      let(:load_path) { Pathname.new(fixtures).relative_path_from(Pathname.pwd) }
      it "loads the configuration" do
        assert_equal "licensed-yml", app["name"]
      end
    end

    describe "an absolute directory path" do
      let(:load_path) { fixtures }
      it "loads a config from an absolute directory path" do
        assert_equal "licensed-yml", app["name"]
      end
    end

    describe "a relative file path" do
      let(:load_path) do
        file = File.join(fixtures, "config.yml")
        Pathname.new(file).relative_path_from(Pathname.pwd)
      end
      it "loads a config from a relative file path" do
        assert_equal "config-yml", app["name"]
      end
    end

    describe "an absolute file path" do
      let(:load_path) { File.join(fixtures, "config.yml") }
      it "loads a config from an absolute file path" do
        assert_equal "config-yml", app["name"]
      end
    end

    describe "a json configuration file" do
      let(:load_path) { File.join(fixtures, ".licensed.json") }
      it "loads json configurations" do
        assert_equal "licensed-json", app["name"]
      end
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

  describe "apps" do
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
    let(:options) { { "apps" => apps } }
    let(:config) { Licensed::Configuration.new(options) }

    it "returns a default app if apps not specified in configuration" do
      options.delete "apps"
      assert_equal 1, config.apps.size
      app = config.apps.first
      assert_equal Pathname.pwd, app.source_path
      assert_equal app.root.join(Licensed::AppConfiguration::DEFAULT_CACHE_PATH),
                   app.cache_path
      assert_equal File.basename(Dir.pwd), app["name"]
    end

    it "expands source_path patterns in default app" do
      options.delete "apps"
      options["source_path"] = File.expand_path("../fixtures/*", __FILE__)
      expected_source_paths = Dir.glob(options["source_path"]).select { |p| File.directory?(p) }
      expected_source_paths.each do |source_path|
        app = config.apps.find { |app| app["source_path"] == source_path }
        assert app
        dir_name = File.basename(source_path)
        assert_equal app.root.join(Licensed::AppConfiguration::DEFAULT_CACHE_PATH, dir_name),
                     app.cache_path
        assert_equal dir_name, app["name"]
      end
    end

    it "returns configured apps" do
      assert_equal 2, config.apps.size
      assert_equal "app1", config.apps[0]["name"]
      assert_equal "app2", config.apps[1]["name"]
    end

    it "includes default options" do
      options["default"] = "default"
      config.apps.each do |app|
        assert_equal "default", app["default"]
      end
    end

    it "can override default options" do
      options["default"] = "default"
      apps[0]["default"] = "override"
      assert_equal "override", config.apps[0]["default"]
    end

    it "expands patterns in configured apps" do
      apps.clear
      apps << { "source_path" => File.expand_path("../fixtures/*", __FILE__) }
      expected_source_paths = Dir.glob(apps[0]["source_path"]).select { |p| File.directory?(p) }
      expected_source_paths.each do |source_path|
        app = config.apps.find { |app| app["source_path"] == source_path }
        assert app
        dir_name = File.basename(source_path)
        assert_equal app.root.join(Licensed::AppConfiguration::DEFAULT_CACHE_PATH, dir_name),
                     app.cache_path
        assert_equal dir_name, app["name"]
      end
    end

    it "assigns uniqueness to explicitly configured values" do
      cache_path = ".test_licenses"
      name = "test"
      apps.clear
      apps << {
        "source_path" => File.expand_path("../fixtures/*", __FILE__),
        "cache_path" => cache_path,
        "name" => name
      }
      expected_source_paths = Dir.glob(apps[0]["source_path"]).select { |p| File.directory?(p) }
      expected_source_paths.each do |source_path|
        app = config.apps.find { |app| app["source_path"] == source_path }
        assert app
        dir_name = File.basename(source_path)
        assert_equal app.root.join(cache_path, dir_name), app.cache_path
        assert_equal "#{name}-#{dir_name}", app["name"]
      end
    end

    it "does not assign unique cache paths if shared_cache is true" do
      cache_path = ".test_licenses"
      apps.clear
      apps << {
        "source_path" => File.expand_path("../fixtures/*", __FILE__),
        "cache_path" => cache_path,
        "shared_cache" => true
      }
      expected_source_paths = Dir.glob(apps[0]["source_path"]).select { |p| File.directory?(p) }
      expected_source_paths.each do |source_path|
        app = config.apps.find { |app| app["source_path"] == source_path }
        assert app
        assert_equal app.root.join(cache_path), app.cache_path
      end
    end

    it "does not apply an inherited shared_cache setting to an app-configured cache path" do
      cache_path = ".test_licenses"
      name = "test"
      apps.clear
      apps << {
        "source_path" => File.expand_path("../fixtures/*", __FILE__),
        "cache_path" => cache_path
      }
      options["shared_cache"] = true

      expected_source_paths = Dir.glob(apps[0]["source_path"]).select { |p| File.directory?(p) }
      expected_source_paths.each do |source_path|
        app = config.apps.find { |app| app["source_path"] == source_path }
        assert app
        dir_name = File.basename(source_path)
        assert_equal app.root.join(cache_path, dir_name), app.cache_path
      end
    end
  end
end

describe Licensed::AppConfiguration do
  let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
  let(:fixtures) { File.expand_path("../fixtures/config", __FILE__) }

  it "raises an error if source_path is not set" do
    assert_raises ::Licensed::Configuration::LoadError do
      Licensed::AppConfiguration.new
    end
  end

  it "uses a default name" do
    assert_equal "licensed", config["name"]
  end

  it "sets a default cache path with the app name if not configured" do
    assert_equal config.root.join(Licensed::AppConfiguration::DEFAULT_CACHE_PATH, config["name"]),
                 config.cache_path
  end

  it "appends the app name to an inherited cache path" do
    config = Licensed::AppConfiguration.new(
      { "source_path" => Dir.pwd },
      { "cache_path" => "vendor/cache" }
    )
    assert_equal config.root.join("vendor/cache", config["name"]), config.cache_path
  end

  it "does not append the app name to an explicit cache path" do
    config = Licensed::AppConfiguration.new(
      { "source_path" => Dir.pwd, "cache_path" => "vendor/cache" }
    )
    assert_equal config.root.join("vendor/cache"), config.cache_path
    refute config.cache_path.to_s.end_with? config["name"]
  end

  it "applies an inherited shared_cache setting to an inherited cache path" do
    config = Licensed::AppConfiguration.new(
      { "source_path" => Dir.pwd },
      { "shared_cache" => true, "cache_path" => "vendor/cache" }
    )

    assert_equal config.root.join("vendor/cache"), config.cache_path
    refute config.cache_path.to_s.end_with? config["name"]
  end

  it "does not apply an inherited shared_cache setting to the default cache path" do
    config = Licensed::AppConfiguration.new(
      { "source_path" => Dir.pwd },
      { "shared_cache" => true }
    )

    assert_equal config.root.join(Licensed::AppConfiguration::DEFAULT_CACHE_PATH, config["name"]),
                 config.cache_path
  end

  describe "ignore" do
    let(:package) { { "type" => "go", "name" => "github.com/github/licensed/package" } }

    it "marks the dependency as ignored" do
      refute config.ignored?(package)
      config.ignore package
      assert config.ignored?(package)
    end

    describe "with glob patterns" do
      it "does not match trailing ** to multiple path segments" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "github.com/github/**")
        refute config.ignored?(package)
      end

      it "matches internal ** to multiple path segments" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "github.com/**/package")
        assert config.ignored?(package)
      end

      it "matches trailing * to single path segment" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "github.com/github/licensed/*")
        assert config.ignored?(package)
      end

      it "maches internal * to single path segment" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "github.com/*/licensed/package")
        assert config.ignored?(package)
      end

      it "matches multiple globstars in a pattern" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "**/licensed/*")
        assert config.ignored?(package)
      end

      it "does not match * to multiple path segments" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "github.com/github/*")
        refute config.ignored?(package)
      end

      it "is case insensitive" do
        refute config.ignored?(package)
        config.ignore package.merge("name" => "GITHUB.com/github/**")
        refute config.ignored?(package)
      end
    end
  end

  describe "review" do
    let(:package) { { "type" => "bundler", "name" => "bundler" } }

    it "marks the dependency as reviewed" do
      refute config.reviewed?(package)
      config.review package
      assert config.reviewed?(package)
    end
  end

  describe "allow" do
    it "marks the license as allowed" do
      refute config.allowed?("mit")
      config.allow "mit"
      assert config.allowed?("mit")
    end
  end

  describe "enabled?" do
    it "returns true if source type is enabled" do
      config["sources"]["npm"] = true
      assert config.enabled?("npm")
    end

    it "returns false if source type is disabled" do
      config["sources"]["npm"] = false
      refute config.enabled?("npm")
    end

    it "returns true if no source types are configured" do
      Licensed::Sources::Source.sources.each do |source|
        assert config.enabled?(source.type)
      end
    end

    it "returns true for source types that are not disabled, if no sources are configured enabled" do
      config["sources"]["npm"] = false
      Licensed::Sources::Source.sources - [Licensed::Sources::NPM].each do |source_type|
        assert config.enabled?(source_type)
      end
    end

    it "returns false for source types that are not enabled, if any sources are configured enabled" do
      config["sources"]["npm"] = true
      Licensed::Sources::Source.sources - [Licensed::Sources::NPM].each do |source_type|
        refute config.enabled?(source_type)
      end
    end
  end

  describe "root" do
    it "can be set to a path from a configuration file" do
      file = File.join(fixtures, "root.yml")
      config = Licensed::Configuration.load_from(file).apps.first
      assert_equal File.expand_path("../..", fixtures), config.root.to_s
    end

    it "can be set to true in a configuration file" do
      file = File.join(fixtures, "root_at_configuration.yml")
      config = Licensed::Configuration.load_from(file).apps.first
      assert_equal fixtures, config.root.to_s
    end

    it "defaults to the git repository root" do
      assert_equal Licensed::Git.repository_root, config.root.to_s
    end
  end
end
