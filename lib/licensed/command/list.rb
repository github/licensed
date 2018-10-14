# frozen_string_literal: true
module Licensed
  module Command
    class List
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def run
        @config.apps.each do |app|
          @config.ui.info "Displaying dependencies for #{app["name"]}"
          Dir.chdir app.source_path do
            app.sources.each do |source|
              type = source.class.type

              @config.ui.info "  #{type} dependencies:"

              source_dependencies = dependencies(app, source)
              source_dependencies.each do |dependency|
                @config.ui.info "    Found #{dependency.name} (#{dependency["version"]})"
              end

              @config.ui.confirm "  * #{type} dependencies: #{source_dependencies.size}"
            end
          end
        end
      end

      # Returns an apps non-ignored dependencies, sorted by name
      def dependencies(app, source)
        source.dependencies
              .select { |d| !app.ignored?(d) }
              .sort_by { |d| d.name }
      end

      def success?
        true
      end
    end
  end
end
