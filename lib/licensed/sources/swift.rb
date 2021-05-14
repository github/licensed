# frozen_string_literal: true
require "json"
require "pathname"
require "licensed/sources/helpers/content_versioning"

module Licensed
  module Sources
    class Swift < Source
      include Licensed::Sources::ContentVersioning

      class Dependency < Licensed::Dependency
        attr_reader :url

        def initialize(name:, url:, version:, path:, search_root: nil, errors: [], metadata: {})
          @url = url
          super name: name, version: version, path: path, errors: errors, metadata: metadata, search_root: search_root
        end
      end

      def enabled?
        Licensed::Shell.tool_available?("swift") && swift_package?
      end

      def enumerate_dependencies
        Hash[declarations.map { |d| [d.url, d] }]
          .merge(Hash[pins.map { |d| [d.url, d] }])
          .values
      end

      private

      def declarations
        return @declarations if defined?(@declarations)

        @declarations = begin
          json = JSON.parse(dump_package_command)
          json["dependencies"].map do |dependency|
            Dependency.new(
              name: dependency["name"],
              url: dependency["url"],
              path: "/Package.swift",
              version: dependency.dig("requirement", "exact") ||
                        dependency.dig("requirement", "range")&.first&.fetch("lowerBound") ||
                        dependency.dig("requirement", "range")&.first&.fetch("upperBound")
            )
          end
        end || []
      end

      def pins
        return @pins if defined?(@pins)

        @pins = begin
          file = "Package.resolved"
          return unless File.exist?(file)

          json = JSON.parse(File.read(file))
          json.dig("object", "pins").map do |pin|
            Dependency.new(
              name: pin["package"],
              url: pin["repositoryURL"],
              path: "/Package.resolved",
              version: pin.dig("state", "version")
            )
          end
        end || []
      end

      def dump_package_command
        args = %w(--skip-update)
        Licensed::Shell.execute("swift", "package", "dump-package", *args)
      end

      def swift_package?
        Licensed::Shell.success?("swift", "package", "describe")
      end
    end
  end
end
