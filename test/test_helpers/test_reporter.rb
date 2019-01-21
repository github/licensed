# frozen_string_literal: true
class TestReporter < Licensed::Reporters::Reporter
  attr_reader :results

  def initialize
    super TestShell.new
  end

  # Make the run report available for tests to examine
  def report_run
    super do |report|
      @results = report
      yield report
    end
  end
end
