# frozen_string_literal: true
module Licensed
  module Command
    class Cache
      attr_reader :config
      attr_reader :reporter
      attr_reader :force

      def initialize(config, reporter = Licensed::Reporters::CacheReporter.new)
        @config = config
        @reporter = reporter
      end

      # Cache any stale or missing license dependency records
      #
      # force - Set to true to for all records to be cached
      #
      # Returns whether the command was a success
      def run(force: false)
        @force = force
        begin
          reporter.report_run do
            config.apps.each { |app| cache_app(app) }
          end
        ensure
          @force = nil
        end

        true
      end

      # Cache any stale or missing dependency records for an application.
      # Will remove any cached records that don't match a current application
      # dependency.
      #
      # app - An application configuration
      #
      # Returns nothing
      def cache_app(app)
        reporter.report_app(app) do
          Dir.chdir app.source_path do
            app.sources.each { |source| cache_source(app, source) }
            clear_stale_cached_records(app)
          end
        end
      end

      # Cache any stale or missing dependency records for a dependency source
      #
      # app - The application configuration for the source
      # source - A dependency source enumerator
      #
      # Returns nothing
      def cache_source(app, source)
        reporter.report_source(source) do
          source.dependencies.each { |dependency| cache_dependency(app, source, dependency) }
        end
      end

      # Cache any stale or missing dependency records for a dependency
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      #
      # Returns nothing
      def cache_dependency(app, source, dependency)
        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        reporter.report_dependency(dependency) do |report|
          cached_record = Licensed::DependencyRecord.read(filename)
          report["cached"] = force || save_dependency_record?(dependency, cached_record)
          if report["cached"]
            # use the cached license value if the license text wasn't updated
            dependency.record["license"] = cached_record["license"] if dependency.record.matches?(cached_record)
            dependency.record.save(filename)
          end
        end
      end

      # Determine if the current dependency's record should be saved.
      # The record should be saved if:
      # 1. there is no cached record
      # 2. the cached record doesn't have a version set
      # 3. the cached record version doesn't match the current dependency version
      #
      # dependency - An application dependency
      # cached_record - A dependency record to compare with the dependency
      #
      # Returns true if dependency's record should be saved
      def save_dependency_record?(dependency, cached_record)
        return true if cached_record.nil?

        cached_version = cached_record["version"]
        return true if cached_version.nil? || cached_version.empty?
        return true if dependency.version != cached_version
        false
      end

      # Clean up cached files that dont match current dependencies
      #
      # app - An application configuration
      #
      # Returns nothing
      def clear_stale_cached_records(app)
        names = app.sources.flat_map do |source|
          source.dependencies.map { |dependency| File.join(source.class.type, dependency.name) }
        end
        Dir.glob(app.cache_path.join("**/*.#{DependencyRecord::EXTENSION}")).each do |file|
          file_path = Pathname.new(file)
          relative_path = file_path.relative_path_from(app.cache_path).to_s
          FileUtils.rm(file) unless names.include?(relative_path.chomp(".#{DependencyRecord::EXTENSION}"))
        end
      end
    end
  end
end
