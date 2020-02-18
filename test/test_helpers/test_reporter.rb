# frozen_string_literal: true
class TestReporter < Licensed::Reporters::Reporter
  attr_reader :report

  def initialize
    super TestShell.new
  end

  # Make the run report available for tests to examine
  def report_run(command)
    super do |report|
      @report = report
      yield report
    end
  end

  # Reports on a dependency in a list command run.
  #
  # dependency - An application dependency
  #
  # Returns the result of the yielded method
  # Note - must be called from inside the `report_run` scope
  def report_dependency(dependency)
    super do |report|
      result = yield report
      report[:dependency] = dependency
      result
    end
  end
end
