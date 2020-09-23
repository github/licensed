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

  def run(**options)
    super do |report|
      report["extra"] = true
      next :skip if options[:skip_run]
    end
  end

  protected

  def run_app(app)
    super do |report|
      report["extra"] = true
      next :skip if options[:skip_app]
    end
  end

  def run_source(app, source)
    options[:source_proc].call(app, source) if options[:source_proc]
    super do |report|
      report["extra"] = true
      next :skip if options[:skip_source]
    end
  end

  def run_dependency(app, source, dependency)
    options[:dependency_proc].call(app, source, dependency) if options[:dependency_proc]
    super do |report|
      report["extra"] = true
      next :skip if options[:skip_dependency]
    end
  end

  def evaluate_dependency(app, source, dependency, report)
    return options[:evaluate_proc].call(app, source, dependency) if options[:evaluate_proc]
    report["evaluated"] = true
    true
  end
end
