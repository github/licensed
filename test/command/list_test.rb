# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::List do
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new }
  let(:command) { Licensed::Command::List.new(config) }
  let(:fixtures) { File.expand_path("../../fixtures", __FILE__) }

  before do
    config.apps.each do |app|
      app.sources.clear
      app.sources << source
    end
  end

  each_source do |source_type|
    describe "with #{source_type}" do
      let(:config_file) { File.join(fixtures, "command/#{source_type.to_s.downcase}.yml") }
      let(:config) { Licensed::Configuration.load_from(config_file) }
      let(:source) { Licensed::Sources.const_get(source_type).new(config) }
      let(:expected_dependency) { config["expected_dependency"] }

      it "lists dependencies" do
        Dir.chdir config.source_path do
          skip "#{source_type} not available" unless source.enabled?
        end

        out, = capture_io { command.run }
        assert_match(/Found #{expected_dependency}/, out)
        assert_match(/#{source.class.type} dependencies:/, out)
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
      assert_equal fixtures, source.dependencies.first["dir"]
    end
  end
end
