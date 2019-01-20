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
          shell.info "Caching dependency records for #{app["name"]}:"
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
          shell.info "  #{source.class.type} dependencies:"
          result = yield report
          shell.confirm "  * #{report.size} #{source.class.type} dependencies"
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

          action = report["cached"] ? "Caching" : "Using"
          shell.info "    #{action} #{dependency.name} (#{dependency.version})"

          result
        end
      end
    end
  end
end
