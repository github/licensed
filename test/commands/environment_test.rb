# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::Environment do
  let(:apps) {
    [
      {
        "name" => "app1",
        "source_path" => Dir.pwd
      },
      {
        "name" => "app2",
        "source_path" => Dir.pwd
      }
    ]
  }
  let(:config) { Licensed::Configuration.new("apps" => apps, "sources" => { "test" => true }) }
  let(:command) { Licensed::Commands::Environment.new(config: config) }

  describe "#run" do
    let(:reporter) { TestReporter.new }

    before do
      Spy.on(command, :create_reporter).and_return(reporter)
    end

    it "reports environment information" do
      command.run

      report = reporter.report
      assert_equal Licensed::Git.git_repo?, report["git_repo"]
    end

    it "reports information for each app" do
      command.run

      config.apps.each do |app|
        report = reporter.report.all_reports.find { |report| report.target == app }
        assert report

        Licensed::Commands::Environment::AppEnvironment.new(app).to_h.each do |key, value|
          assert_equal value, report[key]
        end
      end
    end
  end

  describe "#create_reporter" do
    it "uses a YAML reporter by default" do
      assert command.create_reporter({}).is_a?(Licensed::Reporters::YamlReporter)
    end

    it "uses a YAML reporter when format is set to yaml" do
      assert command.create_reporter(format: "yaml").is_a?(Licensed::Reporters::YamlReporter)
    end

    it "uses a JSON reporter when format is set to json" do
      assert command.create_reporter(format: "json").is_a?(Licensed::Reporters::JsonReporter)
    end
  end
end
