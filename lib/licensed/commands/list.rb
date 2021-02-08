# frozen_string_literal: true
module Licensed
  module Commands
    class List < Command
      # Returns the default reporter to use during the command run
      #
      # options - The options the command was run with
      #
      # Returns a Licensed::Reporters::ListReporter
      def default_reporter(options)
        Licensed::Reporters::ListReporter.new
      end

      protected

      # Run the command for all enumerated dependencies found in a dependency source,
      # recording results in a report.
      # Enumerating dependencies in the source is skipped if a :sources option
      # is provided and the evaluated `source.class.type` is not in the :sources values
      #
      # app - The application configuration for the source
      # source - A dependency source enumerator
      #
      # Returns whether the command succeeded for the dependency source enumerator
      def run_source(app, source)
        super do |report|
          next if Array(options[:sources]).empty?
          next if options[:sources].include?(source.class.type)

          report.warnings << "skipped source"
          :skip
        end
      end

      # Listing dependencies requires no extra work.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns true.
      def evaluate_dependency(app, source, dependency, report)
        report["dependency"] = dependency.name
        report["version"] = dependency.version

        if options[:licenses]
          report["license"] = dependency.license_key
        end

        true
      end
    end
  end
end
