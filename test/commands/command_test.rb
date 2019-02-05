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
      app_report = command.reporter.report.reports.find { |report| report.name == app["name"] }
      assert app_report

      source_report = app_report.reports.find { |report| report.name == "#{app["name"]}.#{TestSource.type}" }
      assert source_report

      assert source_report.reports.find { |report| report.name == "#{app["name"]}.#{TestSource.type}.dependency" }
    end
  end

  it "fails if any of the dependencies fail the command" do
    refute command.run(fail: "app2")
  end

  it "succeeds if all of the dependencies succeed the command" do
    assert command.run
  end

  it "catches shell errors thrown when evaluating an app" do
    app_name = apps.first["name"]
    source_name = "#{app_name}.test"
    refute command.run(raise: source_name)

    report = command.reporter.report.all_reports.find { |report| report.name == app_name }
    assert report
    assert_includes report.errors, "'app1.test' exited with status 0\n"
  end

  it "catches shell errors thrown when evaluating a source" do
    source_name = "#{apps.first["name"]}.test"
    dependency_name = "#{source_name}.dependency"
    refute command.run(raise: dependency_name)

    report = command.reporter.report.all_reports.find { |report| report.name == source_name }
    assert report
    assert_includes report.errors, "'app1.test.dependency' exited with status 0\n"
  end

  it "catches shell errors thrown when evaluating a dependency" do
    dependency_name = "#{apps.first["name"]}.test.dependency"
    dependency_evaluation_name = "#{dependency_name}.evaluate"
    refute command.run(raise: dependency_evaluation_name)

    report = command.reporter.report.all_reports.find { |report| report.name == dependency_name }
    assert report
    assert_includes report.errors, "'app1.test.dependency.evaluate' exited with status 0\n"
  end

  it "reports errors found on a dependency" do
    dependency_name = "#{apps.first["name"]}.test.dependency"
    configuration.apps.first["test"] = { "path" => nil }
    refute command.run
    report = command.reporter.report.all_reports.find { |report| report.name == dependency_name }
    assert report
    assert_includes report.errors, "dependency path not found"
  end
end
