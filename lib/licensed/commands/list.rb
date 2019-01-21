# frozen_string_literal: true
module Licensed
  module Commands
    class List
      attr_reader :config
      attr_reader :reporter

      def initialize(config, reporter = Licensed::Reporters::ListReporter.new)
        @config = config
        @reporter = reporter
      end

      def run
        reporter.report_run do
          config.apps.each { |app| list_app_dependencies(app) }
        end

        true
      end

      def list_app_dependencies(app)
        reporter.report_app(app) do
          Dir.chdir app.source_path do
            app.sources.each { |source| list_source_dependencies(source) }
          end
        end
      end

      def list_source_dependencies(source)
        reporter.report_source(source) do
          source.dependencies
                .sort_by { |dependency| dependency.name }
                .each { |dependency| reporter.report_dependency(dependency) {} }
        end
      end
    end
  end
end
