# frozen_string_literal: true
require "licensee"

module Licensed
  class Dependency < License
    LEGAL_FILES = /\A(AUTHORS|COPYING|NOTICE|LEGAL)(?:\..*)?\z/i

    attr_reader :path
    attr_reader :search_root

    def initialize(path, metadata = {})
      @path = path
      @search_root = metadata.delete("search_root")

      # with licensee providing license_file[:dir],
      # enforcing absolute paths makes life much easier when determining
      # an absolute file path in notices
      unless Pathname.new(path).absolute?
        raise "Dependency path #{path} must be absolute"
      end

      super metadata
    end

    # Returns a Licensee::Projects::FSProject for the dependency path
    def project
      @project ||= Licensee::Projects::FSProject.new(path, search_root: search_root, detect_packages: true, detect_readme: true)
    end

    # Detects license information and sets it on this dependency object.
    #  After calling `detect_license!``, the license is set at
    # `dependency["license"]` and legal text is set to `dependency.text`
    def detect_license!
      self["license"] = license_key
      self.text = [license_text, *notices].join("\n" + TEXT_SEPARATOR + "\n").strip
    end

    # Extract legal notices from the dependency source
    def notices
      local_files.uniq # unique local file paths
           .sort # sorted by the path
           .map { |f| File.read(f) } # read the file contents
           .map(&:strip) # strip whitespace
           .select { |t| t.length > 0 } # files with content only
    end

    # Returns an array of file paths used to locate legal notices
    def local_files
      return [] unless Dir.exist?(path)

      Dir.foreach(path).map do |file|
        next unless file.match(LEGAL_FILES)

        file_path = File.join(path, file)
        next unless File.file?(file_path)

        file_path
      end.compact
    end

    private

    # Returns the Licensee::ProjectFile representing the matched_project_file
    # or remote_license_file
    def project_file
      matched_project_file || remote_license_file
    end

    # Returns the Licensee::LicenseFile, Licensee::PackageManagerFile, or
    # Licensee::ReadmeFile with a matched license, in that order or nil
    # if no license file matched a known license
    def matched_project_file
      @matched_project_file ||= project.matched_files
                                       .select { |f| f.license && !f.license.other? }
                                       .first
    end

    # Returns a Licensee::LicenseFile with the content of the license in the
    # dependency's repository to account for LICENSE files not being distributed
    def remote_license_file
      return @remote_license_file if defined?(@remote_license_file)
      @remote_license_file = Licensed.from_github(self["homepage"])
    end

    # Regardless of the license detected, try to pull the license content
    # from the local LICENSE, remote LICENSE, or the README, in that order
    def license_text
      content_file = project.license_file || remote_license_file || project.readme_file
      content_file.content if content_file
    end

    # Returns a string representing the project's license
    # Note, this will be "other" if a license file was found but the license
    # could not be identified and "none" if no license file was found at all
    def license_key
      if project_file && project_file.license
        project_file.license.key
      elsif project.license_file || remote_license_file
        "other"
      else
        "none"
      end
    end
  end
end
