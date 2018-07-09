# frozen_string_literal: true
require "licensee"

module Licensed
  class Dependency < License
    LEGAL_FILES = /\A(AUTHORS|COPYING|NOTICE|LEGAL)(?:\..*)?\z/i

    attr_reader :path
    attr_reader :search_root

    def initialize(path, metadata = {})
      @search_root = metadata.delete("search_root")
      super metadata

      self.path = path
    end

    # Returns a Licensee::Projects::FSProject for the dependency path
    def project
      @project ||= Licensee::Projects::FSProject.new(path, search_root: search_root, detect_packages: true, detect_readme: true)
    end

    # Sets the path to source dependency license information
    def path=(path)
      # enforcing absolute paths makes life much easier when determining
      # an absolute file path in #notices
      unless Pathname.new(path).absolute?
        raise "Dependency path #{path} must be absolute"
      end

      @path = path
      reset_license!
    end

    # Detects license information and sets it on this dependency object.
    #  After calling `detect_license!``, the license is set at
    # `dependency["license"]` and legal text is set to `dependency.text`
    def detect_license!
      self["license"] = license_key
      self.text = [license_text, *notices].join("\n" + TEXT_SEPARATOR + "\n").rstrip
    end

    # Extract legal notices from the dependency source
    def notices
      local_files.uniq # unique local file paths
           .sort # sorted by the path
           .map { |f| File.read(f) } # read the file contents
           .map(&:rstrip) # strip whitespace
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

    # Resets all local project and license information
    def reset_license!
      @project = nil
      @project_license = nil
      self.delete("license")
      self.text = nil
    end

    # Finds and returns a license from the Licensee::FSProject for this dependency.
    def project_license
      @project_license ||= if project.license && !project.license.other?
        # if Licensee has determined a project to have a specific license, use it!
        project.license
      elsif project.license_files.map(&:license).uniq.size > 1
        # if there are multiple license types found from license files,
        # return 'other'
        Licensee::License.find("other")
      else
        # check other project files if we haven't yet found a license type
        project.licenses.reject(&:other?).first
      end
    end

    # Returns a Licensee::LicenseFile with the content of the license in the
    # dependency's repository to account for LICENSE files not being distributed
    def remote_license_file
      return @remote_license_file if defined?(@remote_license_file)
      @remote_license_file = Licensed.from_github(self["homepage"])
    end

    # Regardless of the license detected, try to pull the license content
    # from the local LICENSE-type files, remote LICENSE, or the README, in that order
    def license_text
      content_files = Array(project.license_files)
      content_files << remote_license_file if content_files.empty? && remote_license_file
      content_files << project.readme_file if content_files.empty? && project.readme_file
      content_files.map(&:content).join("\n#{LICENSE_SEPARATOR}\n")
    end

    # Returns a string representing the project's license
    def license_key
      if project_license && !project_license.other?
        # return a non-other license found from the Licensee
        project_license.key
      elsif remote_license_file && !remote_license_file.license.other?
        # return a non-other license found from the remote source
        remote_license_file.license.key
      elsif project.license || remote_license_file
        # if a license was otherwise found but couldn't be identified to a
        # single license, return "other"
        "other"
      else
        # no license found
        "none"
      end
    end
  end
end
