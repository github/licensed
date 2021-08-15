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
      app_report = command.reporter.report.reports.find { |r| r.name == app["name"] }
      assert app_report

      source_report = app_report.reports.find { |r| r.name == "#{app["name"]}.#{TestSource.type}" }
      assert source_report

      assert source_report.reports.find { |r| r.name == "#{app["name"]}.#{TestSource.type}.dependency" }
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

    reports = command.reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::AppConfiguration) }
    refute_empty reports
    reports.each do |r|
      assert_includes r.errors, "'#{r.name}' exited with status 0\n"
    end
  end

  it "catches shell errors thrown when evaluating a source" do
    proc = lambda { |app, source, _| raise Licensed::Shell::Error.new(["#{app["name"]}.#{source.class.type}"], 0, nil) }
    refute command.run(dependency_proc: proc)

    reports = command.reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::Sources::Source) }
    refute_empty reports
    reports.each do |r|
      assert_includes r.errors, "'#{r.name}' exited with status 0\n"
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

  it "catches dependency record errors thrown when evaluating a dependency" do
    proc = lambda { |app, source, dep| raise Licensed::DependencyRecord::Error.new("dependency record error") }
    refute command.run(evaluate_proc: proc)

    reports = command.reporter.report.all_reports.select { |report| report.target.is_a?(Licensed::Dependency) }
    refute_empty reports
    reports.each do |report|
      assert_includes report.errors, "dependency record error"
    end
  end

  it "reports errors found on a dependency" do
    dependency_name = "#{apps.first["name"]}.test.dependency"
    proc = lambda { |app, source, dep| dep.errors << "error" }
    refute command.run(dependency_proc: proc)
    report = command.reporter.report.all_reports.find { |r| r.name == dependency_name }
    assert report
    assert_includes report.errors, "error"
  end

  it "catches source errors thrown when evaluating a source" do
    proc = lambda { |app, source, _| raise Licensed::Sources::Source::Error.new("#{app["name"]}.#{source.class.type}") }
    refute command.run(dependency_proc: proc)

    reports = command.reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::Sources::Source) }
    refute_empty reports
    reports.each do |r|
      assert_includes r.errors, r.name
    end
  end

  it "catches and reports a non-existent app source path" do
    nonexistent_path = File.join(Dir.pwd, "nonexistent")
    apps.each { |app| app["source_path"] = nonexistent_path }

    refute command.run

    reports = command.reporter.report.all_reports.select { |r| r.target.is_a?(Licensed::AppConfiguration) }
    refute_empty reports
    reports.each do |r|
      assert_includes r.errors, "No such directory #{nonexistent_path}"
    end
  end

  it "allows implementations to add extra data to reports" do
    assert command.run

    report = command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Commands::Command) }
    assert_equal true, report["extra"]

    report = command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::AppConfiguration) }
    assert_equal true, report["extra"]

    report = command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Sources::Source) }
    assert_equal true, report["extra"]

    report = command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    assert_equal true, report["extra"]
  end

  it "allows implementations to skip running a command" do
    assert command.run(skip_run: true)
    assert_nil command.reporter.report
  end

  it "allows implementations to skip running apps" do
    assert command.run(skip_app: true)
    refute command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Sources::Source) }
  end

  it "allows implementations to skip running sources" do
    assert command.run(skip_source: true)
    refute command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
  end

  it "allows implementations to skip evaluating dependencies" do
    assert command.run(skip_dependency: true)
    report = command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Dependency) }
    refute_equal true, report["evaluated"]
  end

  it "skips dependency sources not specified in optional :sources argument" do
    assert command.run(sources: ["alernate"])

    report = command.reporter.report.all_reports.find { |r| r.target.is_a?(Licensed::Sources::Source) }
    refute_empty report.warnings
    assert report.warnings.any? { |w| w == "skipped source" }
  end

  describe "#create_reporter" do
    it "uses a YAML reporter when reporter is set to yaml" do
      assert command.create_reporter(reporter: "yaml").is_a?(Licensed::Reporters::YamlReporter)
    end

    it "uses a JSON reporter when reporter is set to json" do
      assert command.create_reporter(reporter: "json").is_a?(Licensed::Reporters::JsonReporter)
    end

    it "uses a passed in reporter if given" do
      reporter = Licensed::Reporters::StatusReporter.new
      assert_equal reporter, command.create_reporter(reporter: reporter)
    end

    it "uses the commands default_reporter by default" do
      assert command.create_reporter({}).is_a?(TestReporter)
    end
  end
end
