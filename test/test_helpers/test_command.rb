# frozen_string_literal: true
class TestCommand < Licensed::Commands::Command
  protected

  def evaluate_dependency(app, source, dependency, report)
    return true unless options[:fail]
    options[:fail] != app["name"]
  end
end
