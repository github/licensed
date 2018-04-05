# frozen_string_literal: true
require "yaml"

module Licensed
  module Command
    class Status
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def allowed_or_reviewed?(app, dependency)
        app.allowed?(dependency) || app.reviewed?(dependency)
      end

      def app_dependencies(app)
        app.sources.flat_map(&:dependencies).select { |d| !app.ignored?(d) }
      end

      def run
        @results = @config.apps.flat_map do |app|
          Dir.chdir app.source_path do
            dependencies = app_dependencies(app)
            @config.ui.info "Checking licenses for #{app['name']}: #{dependencies.size} dependencies"

            results = dependencies.map do |dependency|
              filename = app.cache_path.join(dependency["type"], "#{dependency["name"]}.txt")

              warnings = []

              # verify cached license data for dependency
              if File.exist?(filename)
                license = License.read(filename)

                if license["version"] != dependency["version"]
                  warnings << "cached license data out of date"
                end
                warnings << "missing license text" if license.license_text.empty?
                unless allowed_or_reviewed?(app, license)
                  warnings << "license needs reviewed: #{license["license"]}."
                end
              else
                warnings << "cached license data missing"
              end

              if warnings.size > 0
                @config.ui.error("F", false)
                [filename, warnings]
              else
                @config.ui.confirm(".", false)
                nil
              end
            end.compact

            unless results.empty?
              @config.ui.warn "\n\nWarnings:"

              results.each do |filename, warnings|
                @config.ui.info "\n#{filename}:"
                warnings.each do |warning|
                  @config.ui.error "  - #{warning}"
                end
              end
            end

            puts "\n#{dependencies.size} dependencies checked, #{results.size} warnings found."
            results
          end
        end
      end

      def success?
        @results.empty?
      end
    end
  end
end
