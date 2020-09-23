# frozen_string_literal: true

module CommandTestHelpers
  def run_command(**options)
    if defined?(reporter) && !options.key?(:reporter)
      # automatically set the defined reporter if a reporter is not explicitly set
      options = options.merge(reporter: reporter)
    end

    # expects the test class to define "command"
    command.run(**options)
  end
end
