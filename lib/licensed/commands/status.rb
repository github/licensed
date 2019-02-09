# frozen_string_literal: true
require "yaml"

module Licensed
  module Commands
    class Status < Command
      def initialize(config:, reporter: Licensed::Reporters::StatusReporter.new)
        super(config: config, reporter: reporter)
      end

      protected

      # Verifies that a cached record exists, is up to date and
      # has license data that complies with the licensed configuration.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns whether the dependency has a cached record that is compliant
      # with the licensed configuration.
      def evaluate_dependency(app, source, dependency, report)
        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        report["filename"] = filename

        cached_record = cached_record(filename)
        if cached_record.nil?
          report.errors << "cached dependency record not found"
        else
          report.errors << "cached dependency record out of date" if cached_record["version"] != dependency.version
          report.errors << "missing license text" if cached_record.licenses.empty?
          report.errors << "license needs review: #{cached_record["license"]}" unless allowed_or_reviewed?(app, cached_record)
        end

        report.errors.empty?
      end

      def allowed_or_reviewed?(app, dependency)
        app.allowed?(dependency) || app.reviewed?(dependency)
      end

      def cached_record(filename)
        return nil unless File.exist?(filename)
        DependencyRecord.read(filename)
      end
    end
  end
end
