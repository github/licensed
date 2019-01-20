# frozen_string_literal: true
module Licensed
  module Reporters
    class Reporter
      class ReportingError < StandardError; end;

      def initialize(shell = Licensed::UI::Shell.new)
        @shell = shell
      end

      # Generate a report for a licensed command execution
      # Yields a report object which can be used to view or add
      # data generated for this run
      #
      # Returns the result of the yielded method
      def report_run
        result = nil
        @run_report = {}
        begin
          result = yield @run_report
        ensure
          @run_report = nil
        end

        result
      end

      # Generate a report for a licensed app configuration
      # Yields a report object which can be used to view or add
      # data generated for this app
      #
      # app - An application configuration
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_app(app)
        raise ReportingError.new("Cannot call report_app with active app context") unless @app_report.nil?
        raise ReportingError.new("Call report_run before report_app") if @run_report.nil?
        result = nil
        @app_report = {}
        begin
          result = yield @app_report
        ensure
          @run_report[app["name"]] = @app_report
          @app_report = nil
        end

        result
      end

      # Generate a report for a licensed dependency source enumerator
      # Yields a report object which can be used to view or add
      # data generated for this dependency source
      #
      # source - A dependency source enumerator
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_app` scope
      def report_source(source)
        raise ReportingError.new("Cannot call report_source with active source context") unless @source_report.nil?
        raise ReportingError.new("Call report_app before report_source") if @app_report.nil?
        result = nil
        @source_report = {}
        begin
          result = yield @source_report
        ensure
          @app_report[source.class.type] = @source_report
          @source_report = nil
        end

        result
      end

      # Generate a report for a licensed dependency
      # Yields a report object which can be used to view or add
      # data generated for this dependency
      #
      # dependency - An application dependency
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_source` scope
      def report_dependency(dependency)
        raise ReportingError.new("Call report_source before report_dependency") if @source_report.nil?

        dependency_report = {}
        @source_report[dependency.name] = dependency_report
        yield dependency_report
      end

      protected

      attr_reader :shell
    end
  end
end
