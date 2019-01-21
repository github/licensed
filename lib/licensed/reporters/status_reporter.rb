# frozen_string_literal: true
require "byebug"

module Licensed
  module Reporters
    class StatusReporter < Reporter
      # Generate a report for a licensed status command run
      # Shows the errors found when checking status, as well as
      # overall number of dependencies checked
      #
      # Returns the result of the yielded method
      def report_app(app)
        super do |report|
          shell.info "Checking cached dependency records for #{app["name"]}"

          result = yield report

          dependencies_count = report.sum { |_, dependency_reports| dependency_reports.size }
          error_data = report.flat_map do |source_type, dependency_reports|
            dependency_reports.reject { |_, data| data["errors"].nil? || data["errors"].empty? }
                              .map { |name, data| data.merge("source" => source_type, "dependency" => name) }
          end

          error_count = error_data.flat_map { |data| data["errors"] }.size
          if error_count > 0
            shell.newline
            shell.newline
            shell.error "Errors:"
            error_data.each do |data|
              display_name = [data["source"], data["dependency"]].join(".")
              display_metadata = data.reject { |k, _| k == "errors" || k == "source" || k == "dependency" }
                                     .map { |k, v| "#{k}: #{v}" }
                                     .join(", ")

              shell.newline
              shell.error "* #{display_name}"
              shell.error "  #{display_metadata}" unless display_metadata.empty?
              data["errors"].each do |error|
               shell.error "    - #{error}"
              end
            end
          end

          shell.newline
          shell.info "#{dependencies_count} dependencies checked, #{error_count} errors found."

          result
        end
      end

      # Reports on a dependency in a status command run.
      # Shows whether the dependency's status is valid in dot format
      #
      # dependency - An application dependency
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_dependency(dependency)
        super do |report|
          result = yield report

          if report["errors"].nil? || report["errors"].empty?
            shell.confirm(".", false)
          else
            shell.error("F", false)
          end

          result
        end
      end
    end
  end
end
