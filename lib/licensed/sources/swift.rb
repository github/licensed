# frozen_string_literal: true
require "json"
require "pathname"
require "uri"

require "licensed/sources/helpers/content_versioning"

module Licensed
  module Sources
    class Swift < Source
      def enabled?
        return unless Licensed::Shell.tool_available?("swift") && swift_package?
        File.exist?(package_resolved_file_path)
      end

      def enumerate_dependencies
        pins.map { |pin|
          Dependency.new(
            name: pin["package"],
            path: dependency_path_for_url(pin["repositoryURL"]),
            version: pin.dig("state", "version")
          )
        }
      end

      private

      def pins
        return @pins if defined?(@pins)

        @pins = begin
          json = JSON.parse(File.read(package_resolved_file_path))
          json.dig("object", "pins")
        rescue JSON::ParserError => e
          message = "Licensed was unable to parse the Package.resolved file'. JSON Error: #{e.message}"
          raise Licensed::Sources::Source::Error, message
        end
      end

      def dependency_path_for_url(url)
        last_path_component = URI(url).path.split('/').last.sub(/\.git$/, '')
        File.join(config.pwd, ".build", "checkouts", last_path_component)
      end

      def package_resolved_file_path
        File.join(config.pwd, "Package.resolved")
      end

      def swift_package?
        Licensed::Shell.success?("swift", "package", "describe")
      end
    end
  end
end
