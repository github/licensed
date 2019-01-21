# frozen_string_literal: true
require "yaml"

module Licensed
  module Command
    class Status
      attr_reader :config
      attr_reader :reporter

      def initialize(config, reporter = Licensed::Reporters::StatusReporter.new)
        @config = config
        @reporter = reporter
      end

      def allowed_or_reviewed?(app, dependency)
        app.allowed?(dependency) || app.reviewed?(dependency)
      end

      def run
        reporter.report_run do
          config.apps.map { |app| verify_app(app) }.all?
        end
      end

      def verify_app(app)
        reporter.report_app(app) do
          Dir.chdir app.source_path do
            app.sources.map { |source| verify_source(app, source) }.all?
          end
        end
      end

      def verify_source(app, source)
        reporter.report_source(source) do
          source.dependencies.map { |dependency| verify_dependency(app, source, dependency) }.all?
        end
      end

      def verify_dependency(app, source, dependency)
        reporter.report_dependency(dependency) do |report|
          filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
          cached_record = cached_record(filename)

          errors = []
          if cached_record.nil?
            errors << "cached dependency record not found"
          else
            errors << "cached dependency record out of date" if cached_record["version"] != dependency.version
            errors << "missing license text" if cached_record.licenses.empty?
            errors << "license needs reviewed: #{cached_record["license"]}" unless allowed_or_reviewed?(app, cached_record)
          end

          report["errors"] = errors
          report["filename"] = filename

          errors.empty?
        end
      end

      def cached_record(filename)
        return nil unless File.exist?(filename)
        DependencyRecord.read(filename)
      end
    end
  end
end
