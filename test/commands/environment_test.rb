# frozen_string_literal: true
require "test_helper"
require "test_helpers/command_test_helpers"

describe Licensed::Commands::Environment do
  include CommandTestHelpers

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

    it "reports environment information" do
      run_command

      report = reporter.report
      assert_equal Licensed::Git.git_repo?, report["git_repo"]
    end

    it "reports information for each app" do
      run_command

      config.apps.each do |app|
        report = reporter.report.all_reports.find { |r| r.target == app }
        assert report

        Licensed::Commands::Environment::AppEnvironment.new(app).to_h.each do |key, value|
          assert_equal value, report[key]
        end
      end
    end
  end
end
