# frozen_string_literal: true
module Licensed
  module Commands
    class Command
      attr_reader :config
      attr_reader :reporter
      attr_reader :options

      def initialize(config:, reporter:)
        @config = config
        @reporter = reporter
      end

      # Run the command
      #
      # options - Options to run the command with
      #
      # Returns whether the command was a success
      def run(**options)
        @options = options
        begin
          result = reporter.report_run(self) do
            config.apps.map { |app| run_app(app) }.all?
          end
        ensure
          @options = nil
        end

        result
      end

      protected

      # Run the command for an application configuration.
      #
      # app - An application configuration
      #
      # Returns whether the command succeeded for the application.
      def run_app(app)
        reporter.report_app(app) do |report|
          Dir.chdir app.source_path do
            begin
              app.sources.map { |source| run_source(app, source) }.all?
            rescue Licensed::Shell::Error => err
              report.errors << err.message
              false
            end
          end
        end
      end

      # Run the command for a dependency source enumerator
      #
      # app - The application configuration for the source
      # source - A dependency source enumerator
      #
      # Returns whether the command succeeded for the dependency source enumerator
      def run_source(app, source)
        reporter.report_source(source) do |report|
          begin
            source.dependencies.map { |dependency| run_dependency(app, source, dependency) }.all?
          rescue Licensed::Shell::Error => err
            report.errors << err.message
            false
          end
        end
      end

      # Run the command for a dependency
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      #
      # Returns whether the command succeeded for the dependency
      def run_dependency(app, source, dependency)
        reporter.report_dependency(dependency) do |report|
          begin
            evaluate_dependency(app, source, dependency, report)
          rescue Licensed::Shell::Error => err
            report.errors << err.message
            false
          end
        end
      end

      # Evaluate a dependency for the command.  Must be implemented by a command implementation.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns whether the command succeeded for the dependency
      def evaluate_dependency(app, source, dependency, report)
        raise "`evaluate_dependency` must be implemented by a command"
      end
    end
  end
end
