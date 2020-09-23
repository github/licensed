# frozen_string_literal: true
module Licensed
  module Commands
    class Cache < Command
      # Returns the default reporter to use during the command run
      #
      # options - The options the command was run with
      #
      # Returns a Licensed::Reporters::CacheReporter
      def default_reporter(options)
        Licensed::Reporters::CacheReporter.new
      end

      # Run the command.
      # Removes any cached records that don't match a current application
      # dependency.
      #
      # options - Options to run the command with
      #
      # Returns whether the command was a success
      def run(**options)
        begin
          result = super
          clear_stale_cached_records if result

          result
        ensure
          cache_paths.clear
          files.clear
        end
      end

      protected

      # Run the command for all enumerated dependencies found in a dependency source,
      # recording results in a report.
      # Enumerating dependencies in the source is skipped if a :sources option
      # is provided and the evaluated `source.class.type` is not in the :sources values
      #
      # app - The application configuration for the source
      # source - A dependency source enumerator
      #
      # Returns whether the command succeeded for the dependency source enumerator
      def run_source(app, source)
        super do |report|
          if Array(options[:sources]).any? && !options[:sources].include?(source.class.type)
            report.warnings << "skipped source"
            next :skip
          end

          # add the full cache path to the list of cache paths
          # that should be cleaned up after the command run
          cache_paths << app.cache_path.join(source.class.type)
        end
      end

      # Cache dependency record data.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns true.
      def evaluate_dependency(app, source, dependency, report)
        if dependency.path.empty?
          report.errors << "dependency path not found"
          return false
        end

        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        cached_record = Licensed::DependencyRecord.read(filename)
        if options[:force] || save_dependency_record?(dependency, cached_record)
          if dependency.record.matches?(cached_record)
            # use the cached license value if the license text wasn't updated
            dependency.record["license"] = cached_record["license"]
          elsif cached_record && app.reviewed?(dependency.record)
            # if the license text changed and the dependency is set as reviewed
            # force a re-review of the dependency
            dependency.record["review_changed_license"] = true
          end

          dependency.record.save(filename)
          report["cached"] = true
        end

        if !dependency.exist?
          report.warnings << "expected dependency path #{dependency.path} does not exist"
        end

        # add the absolute dependency file path to the list of files seen during this licensed run
        files << filename.to_s

        true
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
      # Returns nothing
      def clear_stale_cached_records
        cache_paths.each do |cache_path|
          Dir.glob(cache_path.join("**/*.#{DependencyRecord::EXTENSION}")).each do |file|
            next if files.include?(file)

            FileUtils.rm(file)
          end
        end
      end

      # Set of unique cache paths that are evaluted during the run
      def cache_paths
        @cache_paths ||= Set.new
      end

      # Set of unique absolute file paths of cached records evaluted during the run
      def files
        @files ||= Set.new
      end
    end
  end
end
