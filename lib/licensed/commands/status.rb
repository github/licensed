# frozen_string_literal: true
require "yaml"

module Licensed
  module Commands
    class Status < Command
      # Returns the default reporter to use during the command run
      #
      # options - The options the command was run with
      #
      # Returns a Licensed::Reporters::StatusReporter
      def default_reporter(options)
        Licensed::Reporters::StatusReporter.new
      end

      protected

      # Run the comand and set an error message to review the documentation
      # when any errors have been reported
      #
      # report - A Licensed::Report object for this command
      #
      # Returns whether the command succeeded based on the call to super
      def run_command(report)
        super do |result|
          next if result

          report.errors << "Licensed found errors during source enumeration.  Please see https://github.com/github/licensed/tree/master/docs/commands/status.md#status-errors-and-resolutions for possible resolutions."
        end
      end

      # Evaluates a dependency for any compliance errors.
      # Checks a dependency against either a cached metadata record or
      # reviewed entries in the configuration file.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns whether the dependency is compliant
      # with the licensed configuration.
      def evaluate_dependency(app, source, dependency, report)
        report["version"] = dependency.version

        if data_source == "configuration"
          record = dependency.record
        else
          filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
          report["filename"] = filename
          record = cached_record(filename)
        end

        if record.nil?
          report["license"] = nil
          report.errors << "cached dependency record not found"
        else
          report["license"] = record["license"]
          report.errors << "dependency record out of date" if record["version"] != dependency.version
          report.errors << "missing license text" if record.licenses.empty?
          if record["review_changed_license"]
            report.errors << "license text has changed and needs re-review. if the new text is ok, remove the `review_changed_license` flag from the cached record"
          elsif license_needs_review?(app, record)
            report.errors << needs_review_error_message(app, record)
          end
        end

        report["allowed"] = report.errors.empty?
      end

      # Returns true if a cached record needs further review based on the
      # record's license(s) and the app's configuration
      def license_needs_review?(app, record)
        # review is not needed if the record is set as reviewed
        return false if app.reviewed?(record, match_version: data_source == "configuration")

        # review is not needed if the top level license is allowed
        return false if app.allowed?(record["license"])

        # the remaining checks are meant to allow records marked as "other"
        # that have multiple licenses, all of which are allowed

        # review is needed for non-"other" licenses
        return true unless record["license"] == "other"

        licenses = record.licenses.map { |license| license_from_text(license.text) }

        # review is needed when there is only one license notice
        # this is a performance optimization for the single license case
        return true unless licenses.length > 1

        # review is needed if any license notices don't represent an allowed license
        licenses.any? { |license| !app.allowed?(license) }
      end

      def needs_review_error_message(app, record)
        return "license needs review: #{record["license"]}" if data_source == "files"

        error = "dependency needs review"

        # look for an unversioned reviewed list match
        if app.reviewed?(record, match_version: false)
          error += ", unversioned 'reviewed' match found: #{record["name"]}"
        end

        # look for other version matches in reviewed list
        possible_matches = app.reviewed_versions(record)
        if possible_matches.any?
          error += ", possible 'reviewed' matches found at other versions: #{possible_matches.join(", ")}"
        end

        error
      end

      def data_source
        options[:data_source] || "files"
      end

      def cached_record(filename)
        return nil unless File.exist?(filename)
        DependencyRecord.read(filename)
      end

      # Returns a license key based on the content from a cached records `licenses`
      # entry content
      def license_from_text(text)
        licenses = [
          Licensee::ProjectFiles::LicenseFile.new(text).license&.key,
          Licensee::ProjectFiles::ReadmeFile.new(text).license&.key,
          "other"
        ].compact

        licenses.sort_by { |license| license != "other" ? 0 : 1 }.first
      end
    end
  end
end
