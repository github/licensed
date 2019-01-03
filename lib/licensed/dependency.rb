# frozen_string_literal: true
require "licensee"

module Licensed
  class Dependency < Licensee::Projects::FSProject
    LEGAL_FILES_PATTERN = /(AUTHORS|NOTICE|LEGAL)(?:\..*)?\z/i

    attr_reader :name

    def initialize(name:, path:, search_root: nil, metadata: {})
      # enforcing absolute paths makes life much easier when determining
      # an absolute file path in #notices
      unless Pathname.new(path).absolute?
        raise ArgumentError, "Dependency path #{path} must be absolute"
      end

      @name = name
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
                   .map(&:content)
    end

    # Returns legal notices found at the dependency path
    def notice_contents
      notice_files.sort # sorted by the path
                  .map { |f| File.read(f).rstrip } # read the file contents
                  .select { |t| t.length > 0 } # files with content only
    end

    # Returns an array of file paths used to locate legal notices
    def notice_files
      return [] unless dir_path.exist?

      Dir.glob(dir_path.join("*"))
         .grep(LEGAL_FILES_PATTERN)
         .select { |path| File.file?(path) }
    end

    private

    # Returns the metadata that represents this dependency.  This metadata
    # is written to YAML in the dependencys cached text file
    def license_metadata
      {
        "name" => name, # name can be overriden by a name given in metadata
      }.merge(
        @metadata
      ).merge({
        "license" => license_key # license determination overrides metadata
      })
    end
  end
end
