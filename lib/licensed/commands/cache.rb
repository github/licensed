# frozen_string_literal: true
module Licensed
  module Commands
    class Cache < Command
      def initialize(config:, reporter: Licensed::Reporters::CacheReporter.new)
        super(config: config, reporter: reporter)
      end

      protected

      # Run the command for an application configuration.
      # Will remove any cached records that don't match a current application
      # dependency.
      #
      # app - An application configuration
      #
      # Returns whether the command succeeded for the application.
      def run_app(app)
        result = super
        clear_stale_cached_records(app)
        result
      end

      # Run the command for a dependency
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      #
      # Returns true
      def run_dependency(app, source, dependency)
        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        reporter.report_dependency(dependency) do |report|
          cached_record = Licensed::DependencyRecord.read(filename)
          report["cached"] = options[:force] || save_dependency_record?(dependency, cached_record)
          if report["cached"]
            # use the cached license value if the license text wasn't updated
            dependency.record["license"] = cached_record["license"] if dependency.record.matches?(cached_record)
            dependency.record.save(filename)
          end

          true
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
