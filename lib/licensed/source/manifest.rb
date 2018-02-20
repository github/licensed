# frozen_string_literal: true
require "pathname/common_prefix"

module Licensed
  module Source
    class Manifest
      def initialize(config)
        @config = config
      end

      def enabled?
        @config.enabled?(type) && File.exist?(manifest_path)
      end

      def type
        "manifest"
      end

      def dependencies
        @dependencies ||= packages.map do |package_name, sources|
          Dependency.new(sources_license_path(sources), {
            "type"     => type,
            "name"     => package_name,
            "version"  => package_version(sources)
          })
        end
      end

      # Returns the top-most directory that is common to all paths in `sources`
      def sources_license_path(sources)
        common_prefix = Pathname.common_prefix(*sources).to_path

        # don't allow the repo root to be used as common prefix
        # the project this is run for should be excluded from the manifest,
        # or ignored in the config.  any license in the root should be ignored.
        return common_prefix if common_prefix != Licensed::Git.repository_root

        # use the first source file as the license path.
        sources.first
      end

      # Returns the latest git SHA available from `sources`
      def package_version(sources)
        return if sources.nil? || sources.empty?

        sources.map { |s| Licensed::Git.version(s) }
               .compact
               .max_by { |sha| Licensed::Git.commit_date(sha) }
      end

      # Returns a map of package names -> array of full source paths found
      # in the app manifest
      def packages
        manifest.each_with_object({}) do |(src, package_name), hsh|
          next if src.nil? || src.empty?
          hsh[package_name] ||= []
          hsh[package_name] << File.join(Licensed::Git.repository_root, src)
        end
      end

      # Returns parsed manifest data for the app
      def manifest
        case manifest_path.extname.downcase.delete "."
        when "json"
          JSON.parse(File.read(manifest_path))
        when "yml", "yaml"
          YAML.load_file(manifest_path)
        end
      end

      # Returns the manifest location for the app
      def manifest_path
        path = @config["manifest"]["path"] if @config["manifest"]
        return Licensed::Git.repository_root.join(path) if path

        @config.cache_path.join("manifest.json")
      end
    end
  end
end
