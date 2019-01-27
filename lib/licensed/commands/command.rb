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
          result = reporter.report_run do
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
        reporter.report_app(app) do
          Dir.chdir app.source_path do
            app.sources.map { |source| run_source(app, source) }.all?
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
        reporter.report_source(source) do
          source.dependencies.map { |dependency| run_dependency(app, source, dependency) }.all?
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
        raise "run_for_dependency must be implemented by a command"
      end
    end
  end
end
