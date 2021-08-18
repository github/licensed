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

      # Verifies that a cached record exists, is up to date and
      # has license data that complies with the licensed configuration.
      #
      # app - The application configuration for the dependency
      # source - The dependency source enumerator for the dependency
      # dependency - An application dependency
      # report - A report hash for the command to provide extra data for the report output.
      #
      # Returns whether the dependency has a cached record that is compliant
      # with the licensed configuration.
      def evaluate_dependency(app, source, dependency, report)
        filename = app.cache_path.join(source.class.type, "#{dependency.name}.#{DependencyRecord::EXTENSION}")
        report["filename"] = filename
        report["version"] = dependency.version

        cached_record = cached_record(filename)
        if cached_record.nil?
          report["license"] = nil
          report.errors << "cached dependency record not found"
        else
          report["license"] = cached_record["license"]
          report.errors << "cached dependency record out of date" if cached_record["version"] != dependency.version
          report.errors << "missing license text" if cached_record.licenses.empty?
          if cached_record["review_changed_license"]
            report.errors << "license text has changed and needs re-review. if the new text is ok, remove the `review_changed_license` flag from the cached record"
          elsif license_needs_review?(app, cached_record)
            report.errors << "license needs review: #{cached_record["license"]}"
          end
        end

        report["allowed"] = report.errors.empty?
      end

      # Returns true if a cached record needs further review based on the
      # record's license(s) and the app's configuration
      def license_needs_review?(app, cached_record)
        # review is not needed if the record is set as reviewed
        return false if app.reviewed?(cached_record)
        # review is not needed if the top level license is allowed
        return false if app.allowed?(cached_record["license"])

        # the remaining checks are meant to allow records marked as "other"
        # that have multiple licenses, all of which are allowed

        # review is needed for non-"other" licenses
        return true unless cached_record["license"] == "other"

        licenses = cached_record.licenses.map { |license| license_from_text(license.text) }

        # review is needed when there is only one license notice
        # this is a performance optimization for the single license case
        return true unless licenses.length > 1

        # review is needed if any license notices don't represent an allowed license
        licenses.any? { |license| !app.allowed?(license) }
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
