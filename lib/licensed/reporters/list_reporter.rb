# frozen_string_literal: true

module Licensed
  module Reporters
    class ListReporter < Reporter
      # Reports on an application configuration in a list command run
      #
      # app - An application configuration
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_app(app)
        super do |report|
          shell.info "Listing dependencies for #{app["name"]}"
          yield report
        end
      end

      # Reports on a dependency source enumerator in a list command run.
      # Shows the type and count of dependencies found by the source.
      #
      # source - A dependency source enumerator
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_source(source)
        super do |report|
          shell.info "  #{source.class.type}"
          result = yield report

          errored_reports = report.all_reports.select { |report| report.errors.any? }.to_a
          if errored_reports.any?
            shell.newline
            shell.error "  * Errors:"
            errored_reports.each do |report|
              display_metadata = report.map { |k, v| "#{k}: #{v}" }.join(", ")

              shell.error "    * #{report.name}"
              shell.error "    #{display_metadata}" unless display_metadata.empty?
              report.errors.each do |error|
                shell.error "      - #{error}"
              end
              shell.newline
            end
          else
            shell.confirm "  * #{report.reports.size} #{source.class.type} dependencies"
          end

          result
        end
      end

      # Reports on a dependency in a list command run.
      #
      # dependency - An application dependency
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_dependency(dependency)
        super do |report|
          result = yield report
          shell.info "    #{dependency.name} (#{dependency.version})"

          result
        end
      end
    end
  end
end
