# frozen_string_literal: true
module Licensed
  module Commands
    class Notices < Command
      # Returns the default reporter to use during the command run
      #
      # options - The options the command was run with
      #
      # Returns a Licensed::Reporters::CacheReporter
      def default_reporter(options)
        Licensed::Reporters::NoticesReporter.new
      end

      protected

      # Load stored dependency record data to add to the notices report.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns true.
      def evaluate_dependency(app, source, dependency, report)
        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        report["cached_record"] = Licensed::DependencyRecord.read(filename)
        if !report["cached_record"]
          report.warnings << "expected cached record not found at #{filename}"
        end

        true
      end
    end
  end
end
