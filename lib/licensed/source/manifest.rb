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
        File.exist?(manifest_path) || generate_manifest?
      end

      def dependencies
        @dependencies ||= packages.map do |package_name, sources|
          Licensed::Source::Manifest::Dependency.new(sources, {
              "type"     => Manifest.type,
              "name"     => package_name,
              "version"  => package_version(sources)
            }
          )
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

      # Returns parsed or generated manifest data for the app
      def manifest
        return generate_manifest if generate_manifest?

        case manifest_path.extname.downcase.delete "."
        when "json"
          JSON.parse(File.read(manifest_path))
        when "yml", "yaml"
          YAML.load_file(manifest_path)
        end
      end

      # Returns the manifest location for the app
      def manifest_path
        path = @config.dig("manifest", "path")
        return Licensed::Git.repository_root.join(path) if path

        @config.cache_path.join("manifest.json")
      end

      # Returns whether a manifest should be generated automatically
      def generate_manifest?
        !File.exist?(manifest_path) && !@config.dig("manifest", "dependencies").nil?
      end

      # Returns a manifest of files generated automatically based on patterns
      # set in the licensed configuration file
      def generate_manifest
        verify_configured_dependencies!
        configured_dependencies.each_with_object({}) do |(name, files), hsh|
          files.each { |f| hsh[f] = name }
        end
      end

      # Verify that the licensed configuration file is valid for the current project.
      # Raises errors for issues found with configuration
      def verify_configured_dependencies!
        # verify that dependencies are configured
        if configured_dependencies.empty?
          raise "The manifest \"dependencies\" cannot be empty!"
        end

        # verify all included files match a single configured dependency
        errors = included_files.map do |file|
          matches = configured_dependencies.select { |name, files| files.include?(file) }
                                           .map { |name, files| name }
          case matches.size
          when 0
            "#{file} did not match a configured dependency"
          when 1
            nil
          else
            "#{file} matched multiple configured dependencies: #{matches.join(", ")}"
          end
        end

        errors.compact!
        raise errors.join($/) unless errors.empty?
      end

      # Returns the project dependencies specified from the licensed configuration
      def configured_dependencies
        @configured_dependencies ||= begin
          dependencies = @config.dig("manifest", "dependencies")&.dup || {}

          dependencies.each do |name, patterns|
            # map glob pattern(s) listed for the dependency to a listing
            # of files that match the patterns and are not excluded
            dependencies[name] = files_from_pattern_list(patterns) & included_files
          end

          dependencies
        end
      end

      # Returns the set of project files that are included in dependency evaluation
      def included_files
        @sources ||= all_files - files_from_pattern_list(@config.dig("manifest", "exclude"))
      end

      # Finds and returns all files in the project that match
      # the glob pattern arguments.
      def files_from_pattern_list(patterns)
        return Set.new if patterns.nil? || patterns.empty?

        # evaluate all patterns from the project root
        Dir.chdir Licensed::Git.repository_root do
          Array(patterns).reduce(Set.new) do |files, pattern|
            if pattern.start_with?("!")
              # if the pattern is an exclusion, remove all matching files
              # from the result
              files - Dir.glob(pattern[1..-1], File::FNM_DOTMATCH)
            else
              # if the pattern is an inclusion, add all matching files
              # to the result
              files + Dir.glob(pattern, File::FNM_DOTMATCH)
            end
          end
        end
      end

      # Returns all tracked files in the project
      def all_files
        # remove files if they are tracked but don't exist on the file system
        @all_files ||= Set.new(Licensed::Git.files || [])
                          .delete_if { |f| !File.exist?(f) }
      end

      class Dependency < Licensed::Dependency
        ANY_EXCEPT_COMMENT_CLOSE_REGEX = /(\*(?!\/)|[^\*])*/m.freeze
        HEADER_LICENSE_REGEX = /
          (
            \/\*
            #{ANY_EXCEPT_COMMENT_CLOSE_REGEX}#{Licensee::Matchers::Copyright::COPYRIGHT_SYMBOLS}#{ANY_EXCEPT_COMMENT_CLOSE_REGEX}
            \*\/
          )
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
            indent = nil
            comment.lines.map do |line|
              # find the length of the indent as the number of characters
              # until the first word character
              indent ||= line[/\A([^\w]*)\w/, 1]&.size

              # insert newline for each line until a word character is found
              next "\n" unless indent

              line[/([^\w\r\n]{0,#{indent}})(.*)/m, 2]
            end.join
          end
        end
      end
    end
  end
end
