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
  let(:command) { TestCommand.new(config: configuration) }

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
    fail_proc = lambda { |app, source, dep| app["name"] != "app2" }
    refute command.run(evaluate_proc: fail_proc)
  end

  it "succeeds if all of the dependencies succeed the command" do
    assert command.run
  end

  it "catches shell errors thrown when evaluating an app" do
    proc = lambda { |app, _| raise Licensed::Shell::Error.new(["#{app["name"]}"], 0, nil) }
    refute command.run(source_proc: proc)

    reports = command.reporter.report.all_reports.select { |report| report.target.is_a?(Licensed::AppConfiguration) }
    refute_empty reports
    reports.each do |report|
      assert_includes report.errors, "'#{report.name}' exited with status 0\n"
    end
  end

  it "catches shell errors thrown when evaluating a source" do
    proc = lambda { |app, source, _| raise Licensed::Shell::Error.new(["#{app["name"]}.#{source.class.type}"], 0, nil) }
    refute command.run(dependency_proc: proc)

    reports = command.reporter.report.all_reports.select { |report| report.target.is_a?(Licensed::Sources::Source) }
    refute_empty reports
    reports.each do |report|
      assert_includes report.errors, "'#{report.name}' exited with status 0\n"
    end
  end

  it "catches shell errors thrown when evaluating a dependency" do
    proc = lambda { |app, source, dep| raise Licensed::Shell::Error.new(["#{app["name"]}.#{source.class.type}.#{dep.name}"], 0, nil) }
    refute command.run(evaluate_proc: proc)

    reports = command.reporter.report.all_reports.select { |report| report.target.is_a?(Licensed::Dependency) }
    refute_empty reports
    reports.each do |report|
      assert_includes report.errors, "'#{report.name}' exited with status 0\n"
    end
  end

  it "reports errors found on a dependency" do
    dependency_name = "#{apps.first["name"]}.test.dependency"
    proc = lambda { |app, source, dep| dep.errors << "error" }
    refute command.run(dependency_proc: proc)
    report = command.reporter.report.all_reports.find { |report| report.name == dependency_name }
    assert report
    assert_includes report.errors, "error"
  end

  it "catches source errors thrown when evaluating a source" do
    proc = lambda { |app, source, _| raise Licensed::Sources::Source::Error.new("#{app["name"]}.#{source.class.type}") }
    refute command.run(dependency_proc: proc)

    reports = command.reporter.report.all_reports.select { |report| report.target.is_a?(Licensed::Sources::Source) }
    refute_empty reports
    reports.each do |report|
      assert_includes report.errors, report.name
    end
  end

  it "allows implementations to add extra data to reports with a yielded block" do
    command.run

    report = command.reporter.report.all_reports.find { |report| report.target.is_a?(Licensed::Commands::Command) }
    assert_equal true, report["extra"]

    report = command.reporter.report.all_reports.find { |report| report.target.is_a?(Licensed::AppConfiguration) }
    assert_equal true, report["extra"]

    report = command.reporter.report.all_reports.find { |report| report.target.is_a?(Licensed::Sources::Source) }
    assert_equal true, report["extra"]

    report = command.reporter.report.all_reports.find { |report| report.target.is_a?(Licensed::Dependency) }
    assert_equal true, report["extra"]
  end
end
