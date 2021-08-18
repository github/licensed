# frozen_string_literal: true
class TestReporter < Licensed::Reporters::Reporter
  attr_reader :report

  def initialize
    super TestShell.new
  end

  # Make the run report available for tests to examine
  def begin_report_command(command, report)
    @report = report
  end
end
