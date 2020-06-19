# frozen_string_literal: true

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

          all_reports = report.all_reports

          warning_reports = all_reports.select { |r| r.warnings.any? }.to_a
          if warning_reports.any?
            shell.newline
            shell.warn "Warnings:"
            warning_reports.each do |r|
              display_metadata = r.map { |k, v| "#{k}: #{v}" }.join(", ")

              shell.warn "* #{r.name}"
              shell.warn "  #{display_metadata}" unless display_metadata.empty?
              r.warnings.each do |warning|
                shell.warn "    - #{warning}"
              end
              shell.newline
            end
          end

          errored_reports = all_reports.select { |r| r.errors.any? }.to_a

          dependency_count = all_reports.select { |r| r.target.is_a?(Licensed::Dependency) }.size
          error_count = errored_reports.sum { |r| r.errors.size }

          if error_count > 0
            shell.newline
            shell.error "Errors:"
            errored_reports.each do |r|
              display_metadata = r.map { |k, v| "#{k}: #{v}" }.join(", ")

              shell.error "* #{r.name}"
              shell.error "  #{display_metadata}" unless display_metadata.empty?
              r.errors.each do |error|
                shell.error "    - #{error}"
              end
              shell.newline
            end
          end

          shell.newline
          shell.info "#{dependency_count} dependencies checked, #{error_count} errors found."

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

          if report.errors.empty?
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
