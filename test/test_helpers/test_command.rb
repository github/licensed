# frozen_string_literal: true
class TestCommand < Licensed::Commands::Command
  def reporter
    @test_reporter
  end

  def create_reporter(options)
    @test_reporter ||= super(options)
  end

  def default_reporter(options)
    TestReporter.new
  end

  protected

  def run_command(report)
    report["extra"] = true
    return true if options[:skip_run]
    super
  end

  def run_app(app, report)
    report["extra"] = true
    return true if options[:skip_app]
    super
  end

  def run_source(app, source, report)
    options[:source_proc].call(app, source) if options[:source_proc]
    report["extra"] = true
    return true if options[:skip_source]
    super
  end

  def run_dependency(app, source, dependency, report)
    options[:dependency_proc].call(app, source, dependency) if options[:dependency_proc]
    report["extra"] = true
    return true if options[:skip_dependency]
    super
  end

  def evaluate_dependency(app, source, dependency, report)
    return options[:evaluate_proc].call(app, source, dependency) if options[:evaluate_proc]
    report["evaluated"] = true
    true
  end
end
