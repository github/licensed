# frozen_string_literal: true
module Licensed
  module Commands
    class List < Command
      # Create a reporter to use during a command run
      #
      # options - The options the command was run with
      #
      # Returns a Licensed::Reporters::ListReporter
      def create_reporter(options)
        Licensed::Reporters::ListReporter.new
      end

      protected

      # Listing dependencies requires no extra work.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns true.
      def evaluate_dependency(app, source, dependency, report)
        true
      end
    end
  end
end
