# frozen_string_literal: true
require "pathname/common_prefix"

module Licensed
  module Source
    class Manifest
      def self.type
        "manifest"
      end

      def initialize(config)
        @config = config
      end

      def enabled?
        File.exist?(manifest_path)
      end

      def dependencies
        @dependencies ||= packages.map do |package_name, sources|
          Dependency.new(sources, {
            "type"     => Manifest.type,
            "name"     => package_name,
            "version"  => package_version(sources)
          })
        end
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

      class Dependency < Licensed::Dependency
        ANY_EXCEPT_COMMENT_CLOSE_REGEX = /(\*(?!\/)|[^*])*/m.freeze
        HEADER_LICENSE_REGEX = /
          \/\*
            (#{ANY_EXCEPT_COMMENT_CLOSE_REGEX}#{Licensee::Matchers::Copyright::COPYRIGHT_SYMBOLS}#{ANY_EXCEPT_COMMENT_CLOSE_REGEX})
          \*\/
        /imx.freeze

        def initialize(sources, metadata = {})
          @sources = sources
          super sources_license_path(sources), metadata
        end

        # Detects license information and sets it on this dependency object.
        #  After calling `detect_license!``, the license is set at
        # `dependency["license"]` and legal text is set to `dependency.text`
        def detect_license!
          # if no license key is found for the project, try to create a
          # temporary LICENSE file from unique source file license headers
          if license_key == "none"
            tmp_license_file = write_license_from_source_licenses(self.path, @sources)
            reset_license!
          end

          super
        ensure
          File.delete(tmp_license_file) if tmp_license_file && File.exist?(tmp_license_file)
        end

        private

        # Returns the top-most directory that is common to all paths in `sources`
        def sources_license_path(sources)
          # return the source directory if there is only one source given
          return source_directory(sources[0]) if sources.size == 1

          common_prefix = Pathname.common_prefix(*sources).to_path

          # don't allow the repo root to be used as common prefix
          # the project this is run for should be excluded from the manifest,
          # or ignored in the config.  any license in the root should be ignored.
          return common_prefix if common_prefix != Licensed::Git.repository_root

          # use the first source directory as the license path.
          source_directory(sources.first)
        end

        # Returns the directory for the source.  Checks whether the source
        # is a file or a directory
        def source_directory(source)
          return File.dirname(source) if File.file?(source)
          source
        end

        # Writes any licenses found in source file comments to a LICENSE
        # file at `dir`
        # Returns the path to the license file
        def write_license_from_source_licenses(dir, sources)
          license_path = File.join(dir, "LICENSE")
          File.open(license_path, "w") do |f|
            licenses = source_comment_licenses(sources).uniq
            f.puts(licenses.join("\n#{LICENSE_SEPARATOR}\n"))
          end

          license_path
        end

        # Returns a list of unique licenses parsed from source comments
        def source_comment_licenses(sources)
          comments = sources.select { |s| File.file?(s) }.flat_map do |source|
            content = File.read(source)
            content.scan(HEADER_LICENSE_REGEX).map { |match| match[0] }
          end

          comments.map do |comment|
            # strip leading "*" and whitespace
            comment.lines.map { |line| line[/(\s*\*)?(.*)/m, 2].lstrip }.join
          end
        end
      end
    end
  end
end
