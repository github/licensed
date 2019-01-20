# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::List do
  let(:reporter) { TestReporter.new }
  let(:config) { Licensed::Configuration.new }
  let(:source) { TestSource.new(config) }
  let(:command) { Licensed::Command::List.new(config, reporter) }
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

          command.run
          source_results = reporter.results.values.first
          assert source_results.key?(source_type)
          assert source_results[source_type].key?(expected_dependency)
        end
      end
    end
  end

  it "does not include ignored dependencies" do
    command.run
    dependencies = reporter.results.flat_map { |_, source_results| source_results.values }
                                   .reduce(&:merge)
    assert dependencies.key?("dependency")
    count = dependencies.size

    config.ignore("type" => "test", "name" => "dependency")
    command.run
    dependencies = reporter.results.flat_map { |_, source_results| source_results.values }
                                   .reduce(&:merge)
    refute dependencies.key?("dependency")
    ignored_count = dependencies.size

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
      command.run
      apps.each do |app|
        assert_includes reporter.results.keys, app["name"]
      end
    end
  end

  describe "with app.source_path" do
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      command.run
      assert_equal fixtures, source.dependencies.first.record["dir"]
    end
  end
end
