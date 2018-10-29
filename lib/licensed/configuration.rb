# frozen_string_literal: true
require "pathname"

module Licensed
  class AppConfiguration < Hash
    DEFAULT_CACHE_PATH = ".licenses".freeze
    DEFAULT_CONFIG_FILES = [
      ".licensed.yml".freeze,
      ".licensed.yaml".freeze,
      ".licensed.json".freeze
    ].freeze
    SOURCE_TYPES = Source.constants.map { |c| Source.const_get(c) }.freeze

    attr_reader :ui

    def initialize(options = {}, inherited_options = {})
      super()

      @ui = Licensed::UI::Shell.new

      # update order:
      # 1. anything inherited from root config
      # 2. app defaults
      # 3. explicitly configured app settings
      update(inherited_options)
      update(defaults_for(options, inherited_options))
      update(options)

      self["sources"] ||= {}
      self["reviewed"] ||= {}
      self["ignored"] ||= {}
      self["allowed"] ||= []

      # default the root to the git repository root,
      # or the current directory if no other options are available
      self["root"] ||= Licensed::Git.repository_root || Dir.pwd

      verify_arg "source_path"
      verify_arg "cache_path"
    end

    # Returns the path to the workspace root as a Pathname.
    # Defaults to Licensed::Git.repository_root if not explicitly set
    def root
      Pathname.new(self["root"])
    end

    # Returns the path to the app cache directory as a Pathname
    def cache_path
      root.join(self["cache_path"])
    end

    # Returns the path to the app source directory as a Pathname
    def source_path
      root.join(self["source_path"])
    end

    def pwd
      Pathname.pwd
    end

    # Returns an array of enabled app sources
    def sources
      @sources ||= SOURCE_TYPES.select { |source_class| enabled?(source_class.type) }
                               .map { |source_class| source_class.new(self) }
                               .select(&:enabled?)
    end

    # Returns whether a source type is enabled
    def enabled?(source_type)
      # the default is false if any sources are set to true, true otherwise
      default = !self["sources"].any? { |_, enabled| enabled }
      self["sources"].fetch(source_type, default)
    end

    # Is the given dependency reviewed?
    def reviewed?(dependency)
      Array(self["reviewed"][dependency["type"]]).include?(dependency["name"])
    end

    # Is the given dependency ignored?
    def ignored?(dependency)
      Array(self["ignored"][dependency["type"]]).include?(dependency["name"])
    end

    # Is the license of the dependency allowed?
    def allowed?(dependency)
      Array(self["allowed"]).include?(dependency["license"])
    end

    # Ignore a dependency
    def ignore(dependency)
      (self["ignored"][dependency["type"]] ||= []) << dependency["name"]
    end

    # Set a dependency as reviewed
    def review(dependency)
      (self["reviewed"][dependency["type"]] ||= []) << dependency["name"]
    end

    # Set a license as explicitly allowed
    def allow(license)
      self["allowed"] << license
    end

    private

    def defaults_for(options, inherited_options)
      name = options["name"] || File.basename(options["source_path"])
      cache_path = inherited_options["cache_path"] || DEFAULT_CACHE_PATH
      {
        "name" => name,
        "cache_path" => File.join(cache_path, name)
      }
    end

    def verify_arg(property)
      return if self[property]
      raise Licensed::Configuration::LoadError,
        "App #{self["name"]} is missing required property #{property}"
    end
  end

  class Configuration < AppConfiguration
    class LoadError < StandardError; end

    # Loads and returns a Licensed::Configuration object from the given path.
    # The path can be relative or absolute, and can point at a file or directory.
    # If the path given is a directory, the directory will be searched for a
    # `config.yml` file.
    def self.load_from(path)
      config_path = Pathname.pwd.join(path)
      config_path = find_config(config_path) if config_path.directory?
      Configuration.new(parse_config(config_path))
    end

    def initialize(options = {})
      apps = options.delete("apps") || []
      super(default_options.merge(options))

      self["apps"] = apps.map { |app| AppConfiguration.new(app, options) }
    end

    # Returns an array of the applications for this licensed configuration.
    # If the configuration did not explicitly configure any applications,
    # return self as an application configuration.
    def apps
      return [self] if self["apps"].empty?
      self["apps"]
    end

    private

    # Find a default configuration file in the given directory.
    # File preference is given by the order of elements in DEFAULT_CONFIG_FILES
    #
    # Raises Licensed::Configuration::LoadError if a file isn't found
    def self.find_config(directory)
      config_file = DEFAULT_CONFIG_FILES.map { |file| directory.join(file) }
                                        .find { |file| file.exist? }

      config_file || raise(LoadError, "Licensed configuration not found in #{directory}")
    end

    # Parses the configuration given at `config_path` and returns the values
    # as a Hash
    #
    # Raises Licensed::Configuration::LoadError if the file type isn't known
    def self.parse_config(config_path)
      return {} unless config_path.file?

      extension = config_path.extname.downcase.delete "."
      config = case extension
      when "json"
        JSON.parse(File.read(config_path))
      when "yml", "yaml"
        YAML.load_file(config_path)
      else
        raise LoadError, "Unknown file type #{extension} for #{config_path}"
      end

      expand_config_roots(config, config_path)
      config
    end

    # Expand any roots specified in a configuration file based on the configuration
    # files directory.
    def self.expand_config_roots(config, config_path)
      if config["root"] == true
        config["root"] = File.dirname(config_path)
      elsif config["root"]
        config["root"] = File.expand_path(config["root"], File.dirname(config_path))
      end

      if config["apps"]&.any?
        config["apps"].each { |app_config| expand_config_roots(app_config, config_path) }
      end
    end

    def default_options
      # manually set a cache path without additional name
      {
        "source_path" => Dir.pwd,
        "cache_path" => DEFAULT_CACHE_PATH
      }
    end
  end
end
