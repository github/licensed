# frozen_string_literal: true
module Licensed
  module Reporters
    class CacheReporter < Reporter
      # Reports on an application configuration in a cache command run
      #
      # app - An application configuration
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_app(app)
        super do |report|
          shell.info "Caching dependency records for #{app["name"]}"
          yield report
        end
      end

      # Reports on a dependency source enumerator in a cache command run.
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

          warning_reports = report.all_reports.select { |r| r.warnings.any? }.to_a
          if warning_reports.any?
            shell.newline
            shell.warn "  * Warnings:"
            warning_reports.each do |r|
              display_metadata = r.map { |k, v| "#{k}: #{v}" }.join(", ")

              shell.warn "    * #{r.name}"
              shell.warn "    #{display_metadata}" unless display_metadata.empty?
              r.warnings.each do |warning|
                shell.warn "      - #{warning}"
              end
              shell.newline
            end
          end

          errored_reports = report.all_reports.select { |r| r.errors.any? }.to_a
          if errored_reports.any?
            shell.newline
            shell.error "  * Errors:"
            errored_reports.each do |r|
              display_metadata = r.map { |k, v| "#{k}: #{v}" }.join(", ")

              shell.error "    * #{r.name}"
              shell.error "    #{display_metadata}" unless display_metadata.empty?
              r.errors.each do |error|
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

      # Reports on a dependency in a cache command run.
      # Shows whether the dependency's record was cached or reused.
      #
      # dependency - An application dependency
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_dependency(dependency)
        super do |report|
          result = yield report

          if report.errors.any?
            shell.error "    Error #{dependency.name} (#{dependency.version})"
          elsif report["cached"]
            shell.info "    Caching #{dependency.name} (#{dependency.version})"
          else
            shell.info "    Using #{dependency.name} (#{dependency.version})"
          end

          result
        end
      end
    end
  end
end
