# frozen_string_literal: true
module Licensed
  module Commands
    class Command
      attr_reader :config
      attr_reader :reporter
      attr_reader :options

      def initialize(config:)
        @config = config
      end

      # Run the command
      #
      # options - Options to run the command with
      #
      # Returns whether the command was a success
      def run(**options)
        @options = options
        @reporter = create_reporter(options)
        begin
          result = reporter.report_run(self) do |report|
            # allow additional report data to be given by commands
            if block_given?
              next true if (yield report) == :skip
            end

            config.apps.sort_by { |app| app["name"] }
                       .map { |app| run_app(app) }
                       .all?
          end
        ensure
          @options = nil
          @reporter = nil
        end

        result
      end

      # Creates a reporter to use during a command run
      #
      # options - The options the command was run with
      #
      # Returns the reporter to use during the command run
      def create_reporter(options)
        return options[:reporter] if options[:reporter].is_a?(Licensed::Reporters::Reporter)

        if options[:reporter].is_a?(String)
          klass = "#{options[:reporter].capitalize}Reporter"
          return Licensed::Reporters.const_get(klass).new if Licensed::Reporters.const_defined?(klass)
        end

        default_reporter(options)
      end

      # Returns the default reporter to use during the command run
      #
      # options - The options the command was run with
      #
      # Raises an error
      def default_reporter(options)
        raise "`default_reporter` must be implemented by commands"
      end

      protected

      # Run the command for all enabled sources for an application configuration,
      # recording results in a report.
      #
      # app - An application configuration
      #
      # Returns whether the command succeeded for the application.
      def run_app(app)
        reporter.report_app(app) do |report|
          # ensure the app source path exists before evaluation
          if !Dir.exist?(app.source_path)
            report.errors << "No such directory #{app.source_path}"
            next false
          end

          Dir.chdir app.source_path do
            begin
              # allow additional report data to be given by commands
              if block_given?
                next true if (yield report) == :skip
              end

              app.sources.select(&:enabled?)
                         .sort_by { |source| source.class.type }
                         .map { |source| run_source(app, source) }.all?
            rescue Licensed::Shell::Error => err
              report.errors << err.message
              false
            end
          end
        end
      end

      # Run the command for all enumerated dependencies found in a dependency source,
      # recording results in a report.
      #
      # app - The application configuration for the source
      # source - A dependency source enumerator
      #
      # Returns whether the command succeeded for the dependency source enumerator
      def run_source(app, source)
        reporter.report_source(source) do |report|
          begin
            # allow additional report data to be given by commands
            if block_given?
              next true if (yield report) == :skip
            end

            source.dependencies.sort_by { |dependency| dependency.name }
                               .map { |dependency| run_dependency(app, source, dependency) }
                               .all?
          rescue Licensed::Shell::Error => err
            report.errors << err.message
            false
          rescue Licensed::Sources::Source::Error => err
            report.errors << err.message
            false
          end
        end
      end

      # Run the command for a dependency, evaluating the dependency and
      # recording results in a report.  Dependencies that were found with errors
      # are not evaluated and add any errors to the dependency report.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      #
      # Returns whether the command succeeded for the dependency
      def run_dependency(app, source, dependency)
        reporter.report_dependency(dependency) do |report|
          if dependency.errors?
            report.errors.concat(dependency.errors)
            return false
          end

          begin
            # allow additional report data to be given by commands
            if block_given?
              next true if (yield report) == :skip
            end

            evaluate_dependency(app, source, dependency, report)
          rescue Licensed::DependencyRecord::Error, Licensed::Shell::Error => err
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
