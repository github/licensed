# frozen_string_literal: true
module Licensed
  module Reporters
    class YamlReporter < Reporter
      def report_run(command)
        super do |report|
          result = yield report

          report["apps"] = report.reports.map(&:to_h) if report.reports.any?
          shell.info sanitize(report.to_h).to_yaml

          result
        end
      end

      def report_app(app)
        super do |report|
          result = yield report
          report["sources"] = report.reports.map(&:to_h) if report.reports.any?
          result
        end
      end

      def report_source(source)
        super do |report|
          result = yield report
          report["dependencies"] = report.reports.map(&:to_h) if report.reports.any?
          result
        end
      end

      def sanitize(object)
        case object
        when String, TrueClass, FalseClass, Numeric
          object
        when Array
          object.compact.map { |item| sanitize(item) }
        when Hash
          object.reject { |_, v| v.nil? }
                .map { |k, v| [k.to_s, sanitize(v)] }
                .to_h
        else
          object.to_s
        end
      end
    end
  end
end
