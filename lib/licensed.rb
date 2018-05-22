# frozen_string_literal: true
require "licensed/version"
require "licensed/shell"
require "licensed/configuration"
require "licensed/license"
require "licensed/dependency"
require "licensed/git"
require "licensed/source/bundler"
require "licensed/source/bower"
require "licensed/source/manifest"
require "licensed/source/npm"
require "licensed/source/go"
require "licensed/source/dep"
require "licensed/source/cabal"
require "licensed/command/cache"
require "licensed/command/status"
require "licensed/command/list"
require "licensed/ui/shell"
require "octokit"

module Licensed
  class << self
    attr_accessor :use_github
  end

  self.use_github = true

  GITHUB_URL = %r{\Ahttps://github.com/([a-z0-9]+(-[a-z0-9]+)*/(\w|\.|\-)+)}
  LICENSE_CONTENT_TYPE = "application/vnd.github.drax-preview+json"

  # Load license content from a GitHub url.  Returns nil if the url does not point
  # to a GitHub repository, or if the license content is not found
  def self.from_github(url)
    return unless use_github && match = GITHUB_URL.match(url)

    license_url = Octokit::Repository.path(match[1]) + "/license"
    response = octokit.get license_url, accept: LICENSE_CONTENT_TYPE
    content = Base64.decode64(response["content"]).force_encoding("UTF-8")
    Licensee::ProjectFiles::LicenseFile.new(content, response["name"])
  rescue Octokit::NotFound
    nil
  end

  def self.octokit
    @octokit ||=  Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"])
  end
end
