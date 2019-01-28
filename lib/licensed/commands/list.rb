# frozen_string_literal: true
module Licensed
  module Commands
    class List < Command
      def initialize(config:, reporter: Licensed::Reporters::ListReporter.new)
        super(config: config, reporter: reporter)
      end

      protected

      # Listing dependencies requires not extra work.
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
