# frozen_string_literal: true
class TestCommand < Licensed::Commands::Command
  protected

  def run_dependency(app, source, dependency)
    reporter.report_dependency(dependency) do |report|
      next true unless options[:fail]
      options[:fail] != app["name"]
    end
  end
end
