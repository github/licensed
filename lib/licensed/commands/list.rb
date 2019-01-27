# frozen_string_literal: true
module Licensed
  module Commands
    class List < Command
      def initialize(config:, reporter: Licensed::Reporters::ListReporter.new)
        super(config: config, reporter: reporter)
      end

      protected

      # Run the command for a dependency.  List the dependency in the reporter
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      #
      # Returns true
      def run_dependency(app, source, dependency)
        reporter.report_dependency(dependency) { true }
      end
    end
  end
end
