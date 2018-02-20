# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::Cache do
  let(:config) { Licensed::Configuration.new }
  let(:generator) { Licensed::Command::Cache.new(config) }

  before do
    config.ui.level = "silent"
    FileUtils.rm_rf config.cache_path
  end

  it "extracts license info for each ruby dep" do
    generator.run
    assert config.cache_path.join("rubygem/licensee.txt").exist?
    license = Licensed::License.read(config.cache_path.join("rubygem/licensee.txt"))
    assert_equal "licensee", license["name"]
    assert_equal "mit", license["license"]
  end

  it "cleans up old dependencies" do
    FileUtils.mkdir_p config.cache_path.join("rubygem")
    File.write config.cache_path.join("rubygem/old_dep.txt"), ""
    generator.run
    refute config.cache_path.join("rubygem/old_dep.txt").exist?
  end

  it "cleans up ignored dependencies" do
    FileUtils.mkdir_p config.cache_path.join("rubygem")
    File.write config.cache_path.join("rubygem/licensee.txt"), ""
    config.ignore "type" => "rubygem", "name" => "licensee"
    generator.run
    refute config.cache_path.join("rubygem/licensee.txt").exist?
  end

  it "does not include ignored dependencies in dependency counts" do
    config.ui.level = "info"
    out, _ = capture_io { generator.run }
    count = out.match(/dependencies: (\d+)/)[1].to_i

    FileUtils.mkdir_p config.cache_path.join("rubygem")
    File.write config.cache_path.join("rubygem/licensee.txt"), ""
    config.ignore "type" => "rubygem", "name" => "licensee"

    out, _ = capture_io { generator.run }
    ignored_count = out.match(/dependencies: (\d+)/)[1].to_i
    assert_equal count - 1, ignored_count
  end

  describe "with multiple apps" do
    let(:apps) do
      [
        {
          "name" => "app1",
          "cache_path" => "vendor/licenses/app1",
          "source_path" => Dir.pwd
        },
        {
          "name" => "app2",
          "cache_path" => "vendor/licenses/app2",
          "source_path" => Dir.pwd
        }
      ]
    end
    let(:config) { Licensed::Configuration.new("apps" => apps) }

    it "caches metadata for all apps" do
      generator.run
      assert config["apps"][0].cache_path.join("rubygem/licensee.txt").exist?
      assert config["apps"][1].cache_path.join("rubygem/licensee.txt").exist?
    end
  end

  describe "with app.source_path" do
    let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      config.stub(:enabled?, ->(type) { type == "npm" }) do
        generator.run
      end

      assert config.cache_path.join("npm/autoprefixer.txt").exist?
    end
  end
end
