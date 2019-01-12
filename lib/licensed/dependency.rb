# frozen_string_literal: true
require "licensee"

module Licensed
  class Dependency < Licensee::Projects::FSProject
    LEGAL_FILES_PATTERN = /(AUTHORS|NOTICE|LEGAL)(?:\..*)?\z/i

    attr_reader :name
    attr_reader :version

    def initialize(name:, version:, path:, search_root: nil, metadata: {})
      # enforcing absolute paths makes life much easier when determining
      # an absolute file path in #notices
      unless Pathname.new(path).absolute?
        raise ArgumentError, "Dependency path #{path} must be absolute"
      end

      @name = name
      @version = version
      @metadata = metadata
      super(path, search_root: search_root, detect_readme: true, detect_packages: true)
    end

    def data
      @data ||= License.new(
        metadata: license_metadata,
        licenses: license_contents,
        notices: notice_contents
      )
    end

    # Returns a string representing the dependencys license
    def license_key
      return "none" unless license
      license.key
    end

    # Returns the license text content from all matched sources
    # except the package file, which doesn't contain license text.
    def license_contents
      matched_files.reject { |f| f == package_file }
                   .group_by(&:content)
                   .map { |content, files| { "sources" => content_sources(files), "text" => content } }
    end

    # Returns legal notices found at the dependency path
    def notice_contents
      notice_files.sort # sorted by the path
                  .map { |file| { "sources" => content_sources(file), "text" => File.read(file).rstrip } }
                  .select { |text| text.length > 0 } # files with content only
    end

    # Returns an array of file paths used to locate legal notices
    def notice_files
      return [] unless dir_path.exist?

      Dir.glob(dir_path.join("*"))
         .grep(LEGAL_FILES_PATTERN)
         .select { |path| File.file?(path) }
    end

    private

    # Returns the sources for a group of license or notice file contents
    #
    # Sources are returned as a single string with sources separated by ", "
    def content_sources(files)
      paths = Array(files).map do |file|
        path = if file.is_a?(Licensee::ProjectFiles::ProjectFile)
          dir_path.join(file[:dir], file[:name])
        else
          Pathname.new(file).expand_path(dir_path)
        end

        if path.fnmatch?(dir_path.join("**").to_path)
          # files under the dependency path return the relative path to the file
          path.relative_path_from(dir_path).to_path
        else
          # otherwise return the source_path as the immediate parent folder name
          # joined with the file name
          path.dirname.basename.join(path.basename).to_path
        end
      end

      paths.join(", ")
    end

    # Returns the metadata that represents this dependency.  This metadata
    # is written to YAML in the dependencys cached text file
    def license_metadata
      {
        # can be overriden by values in @metadata
        "name" => name,
        "version" => version
      }.merge(
        @metadata
      ).merge({
        # overrides all other values
        "license" => license_key
      })
    end
  end
end
