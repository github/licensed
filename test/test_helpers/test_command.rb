# frozen_string_literal: true
class TestCommand < Licensed::Commands::Command
  def initialize(config:, reporter: TestReporter.new)
    super(config: config)
    @test_reporter = reporter
  end

  def reporter
    @test_reporter
  end

  def create_reporter(options)
    @test_reporter
  end

  def run(**options)
    super do |report|
      report["extra"] = true
    end
  end

  protected

  def run_app(app)
    super do |report|
      report["extra"] = true
    end
  end

  def run_source(app, source)
    options[:source_proc].call(app, source) if options[:source_proc]
    super do |report|
      report["extra"] = true
    end
  end

  def run_dependency(app, source, dependency)
    options[:dependency_proc].call(app, source, dependency) if options[:dependency_proc]
    super do |report|
      report["extra"] = true
    end
  end

  def evaluate_dependency(app, source, dependency, report)
    return options[:evaluate_proc].call(app, source, dependency) if options[:evaluate_proc]
    true
  end
end
