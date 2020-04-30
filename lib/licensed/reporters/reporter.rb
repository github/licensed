# frozen_string_literal: true
module Licensed
  module Reporters
    class Reporter
      class Report < Hash
        attr_reader :name
        attr_reader :target
        def initialize(name:, target:)
          super()
          @name = name
          @target = target
        end

        def reports
          @reports ||= []
        end

        def errors
          @errors ||= []
        end

        def warnings
          @warnings ||= []
        end

        def all_reports
          result = []
          result << self
          result.push(*reports.flat_map(&:all_reports))
        end

        # Returns the data from the report as a hash
        def to_h
          # add name, errors and warnings if they have real data
          output = {}
          output["name"] = name unless name.to_s.empty?
          output["errors"] = errors.dup if errors.any?
          output["warnings"] = warnings.dup if warnings.any?

          # merge the hash data from the report.  command-specified data always
          # overwrites local data
          output.merge(super)
        end
      end

      class ReportingError < StandardError; end;

      def initialize(shell = Licensed::UI::Shell.new)
        @shell = shell
        @run_report = nil
        @app_report = nil
        @source_report = nil
      end

      # Generate a report for a licensed command execution
      # Yields a report object which can be used to view or add
      # data generated for this run
      #
      # Returns the result of the yielded method
      def report_run(command)
        result = nil
        @run_report = Report.new(name: nil, target: command)
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
        @app_report = Report.new(name: app["name"], target: app)
        begin
          result = yield @app_report
        ensure
          @run_report.reports << @app_report
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
        @source_report = Report.new(name: [@app_report.name, source.class.type].join("."), target: source)
        begin
          result = yield @source_report
        ensure
          @app_report.reports << @source_report
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

        dependency_report = Report.new(name: [@source_report.name, dependency.name].join("."), target: dependency)
        @source_report.reports << dependency_report
        yield dependency_report
      end

      protected

      attr_reader :shell
    end
  end
end
