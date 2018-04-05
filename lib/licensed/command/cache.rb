# frozen_string_literal: true
module Licensed
  module Command
    class Cache
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def run(force: false)
        summary = @config.apps.flat_map do |app|
          app_name = app["name"]
          @config.ui.info "Caching licenes for #{app_name}:"

          # load the app environment
          Dir.chdir app.source_path do

            # map each available app source to it's dependencies
            app.sources.map do |source|
              @config.ui.info "  #{source.type} dependencies:"

              names = []
              cache_path = app.cache_path.join(source.type)

              # exclude ignored dependencies
              dependencies = source.dependencies.select { |d| !app.ignored?(d) }

              # ensure each dependency is cached
              dependencies.each do |dependency|
                name = dependency["name"]
                version = dependency["version"]

                names << name
                filename = cache_path.join("#{name}.txt")

                # try to load existing license from disk
                # or default to a blank license
                license = Licensed::License.read(filename) || Licensed::License.new

                # Version did not change, no need to re-cache
                if !force && version == license["version"]
                  @config.ui.info "    Using #{name} (#{version})"
                  next
                end

                @config.ui.info "    Caching #{name} (#{version})"

                dependency.detect_license!
                # use the cached license value if the license text wasn't updated
                dependency["license"] = license["license"] if dependency.license_text_match?(license)

                dependency.save(filename)
              end

              # Clean up cached files that dont match current dependencies
              Dir.glob(cache_path.join("**/*.txt")).each do |file|
                file_path = Pathname.new(file)
                relative_path = file_path.relative_path_from(cache_path).to_s
                FileUtils.rm(file) unless names.include?(relative_path.chomp(".txt"))
              end

              "* #{app_name} #{source.type} dependencies: #{dependencies.size}"
            end
          end
        end

        @config.ui.confirm "License caching complete!"
        summary.each do |message|
          @config.ui.confirm message
        end
      end

      def success?
        true
      end
    end
  end
end
