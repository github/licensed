# frozen_string_literal: true

module Licensed
  module Reporters
    class NoticesReporter < Reporter
      TEXT_SEPARATOR = "\n\n#{("-" * 5)}\n\n".freeze
      LICENSE_SEPARATOR = "\n#{("*" * 5)}\n".freeze

      # Reports on an application configuration in a notices command run
      #
      # app - An application configuration
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_app(app)
        super do |report|
          filename = app["shared_cache"] ? "NOTICES.#{app["name"]}" : "NOTICES"
          path = app.cache_path.join(filename)
          shell.info "Writing notices for #{app["name"]} to #{path}"

          result = yield report

          File.open(path, "w") do |file|
            file << "THIRD PARTY NOTICES\n"
            file << LICENSE_SEPARATOR
            file << report.all_reports
                          .map { |r| notices(r) }
                          .compact
                          .join(LICENSE_SEPARATOR)
          end

          result
        end
      end

      # Reports on a dependency in a notices command run.
      #
      # dependency - An application dependency
      #
      # Returns the result of the yielded method
      # Note - must be called from inside the `report_run` scope
      def report_dependency(dependency)
        super do |report|
          result = yield report
          shell.warn "* #{report["warning"]}" if report["warning"]
          result
        end
      end

      # Returns notices information for a dependency report
      def notices(report)
        return unless report.target.is_a?(Licensed::Dependency)

        cached_record = report["cached_record"]
        return unless cached_record

        texts = cached_record.licenses.map(&:text)
        texts.concat(cached_record.notices)

        <<~NOTICE
          #{cached_record["name"]}@#{cached_record["version"]}

          #{texts.map(&:strip).reject(&:empty?).compact.join(TEXT_SEPARATOR)}
        NOTICE
      end
    end
  end
end
