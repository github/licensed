# frozen_string_literal: true
require "test_helper"

describe Licensed::Commands::Command do
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
  let(:configuration) { Licensed::Configuration.new("apps" => apps, "sources" => { "test" => true }) }
  let(:command) { TestCommand.new(config: configuration, reporter: TestReporter.new) }

  it "runs a command for all dependencies in the configuration" do
    command.run
    command.config.apps.each do |app|
      app_results = command.reporter.results[app["name"]]
      assert app_results
      source_results = app_results["test"]
      assert source_results
      assert source_results["dependency"]
    end
  end

  it "fails if any of the dependencies fail the command" do
    refute command.run(fail: "app2")
  end

  it "succeeds if all of the dependencies succeed the command" do
    assert command.run
  end
end
