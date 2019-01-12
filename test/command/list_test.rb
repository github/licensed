# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::List do
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new(config) }
  let(:command) { Licensed::Command::List.new(config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
    config.apps.each do |app|
      app.sources.clear
      app.sources << source
    end
  end

  each_source do |source_class|
    describe "with #{source_class.type}" do
      let(:source_type) { source_class.type }
      let(:config_file) { File.join(fixtures, "command/#{source_type}.yml") }
      let(:config) { Licensed::Configuration.load_from(config_file) }
      let(:source) { source_class.new(config) }
      let(:expected_dependency) { config["expected_dependency"] }

      it "lists dependencies" do
        config.apps.each do |app|
          enabled = Dir.chdir(app.source_path) { source.enabled? }
          next unless enabled

          out, = capture_io { command.run }
          assert_match(/Found #{expected_dependency}/, out)
          assert_match(/#{source_type} dependencies:/, out)
        end
      end
    end
  end

  it "does not include ignored dependencies" do
    out, = capture_io { command.run }
    assert_match(/dependency/, out)
    count = out.match(/dependencies: (\d+)/)[1].to_i

    config.ignore("type" => "test", "name" => "dependency")
    out, = capture_io { command.run }
    refute_match(/dependency/, out)
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

    it "lists dependencies for all apps" do
      out, = capture_io { command.run }
      config.apps.each do |app|
        assert_match(/Displaying dependencies for #{app['name']}/, out)
      end
    end
  end

  describe "with app.source_path" do
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      capture_io { command.run }
      assert_equal fixtures, source.dependencies.first.record["dir"]
    end
  end
end
