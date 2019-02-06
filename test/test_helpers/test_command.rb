# frozen_string_literal: true
class TestCommand < Licensed::Commands::Command
  protected

  def run_source(app, source)
    return options[:source_proc].call(app, source) if options[:source_proc]
    super
  end

  def run_dependency(app, source, dependency)
    return options[:dependency_proc].call(app, source, dependency) if options[:dependency_proc]
    super
  end

  def evaluate_dependency(app, source, dependency, report)
    return options[:evaluate_proc].call(app, source, dependency) if options[:evaluate_proc]
    true
  end
end
