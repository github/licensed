# frozen_string_literal: true
require "pathname"

module Licensed
  class AppConfiguration < Hash
    DIRECTORY_NAME_GENERATOR_KEY = "directory_name".freeze
    RELATIVE_PATH_GENERATOR_KEY = "relative_path".freeze
    DEFAULT_RELATIVE_PATH_NAME_SEPARATOR = "-".freeze
    ALL_NAME_GENERATOR_KEYS = [DIRECTORY_NAME_GENERATOR_KEY, RELATIVE_PATH_GENERATOR_KEY].freeze

    DEFAULT_CACHE_PATH = ".licenses".freeze

    # Returns the root for a configuration in following order of precedence:
    # 1. explicitly configured "root" property
    # 2. a found git repository root
    # 3. the current directory
    def self.root_for(configuration)
      configuration["root"] || Licensed::Git.repository_root || Dir.pwd
    end

    def initialize(options = {}, inherited_options = {})
      super()

      # update order:
      # 1. anything inherited from root config
      # 2. explicitly configured app settings
      update(inherited_options)
      update(options)
      verify_arg "source_path"

      self["sources"] ||= {}
      self["reviewed"] ||= {}
      self["ignored"] ||= {}
      self["allowed"] ||= []
      self["root"] = AppConfiguration.root_for(self)
      self["name"] = generate_app_name
      # setting the cache path might need a valid app name.
      # this must come after setting self["name"]
      self["cache_path"] = detect_cache_path(options, inherited_options)
    end

    # Returns the path to the workspace root as a Pathname.
    def root
      @root ||= Pathname.new(self["root"])
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
      @sources ||= Licensed::Sources::Source.sources
                                            .select { |source_class| enabled?(source_class.type) }
                                            .map { |source_class| source_class.new(self) }
    end

    # Returns whether a source type is enabled
    def enabled?(source_type)
      # the default is false if any sources are set to true, true otherwise
      default = !self["sources"].any? { |_, enabled| enabled }
      self["sources"].fetch(source_type, default)
    end

    # Is the given dependency reviewed?
    def reviewed?(dependency)
      Array(self["reviewed"][dependency["type"]]).any? do |pattern|
        File.fnmatch?(pattern, dependency["name"], File::FNM_PATHNAME | File::FNM_CASEFOLD)
      end
    end

    # Is the given dependency ignored?
    def ignored?(dependency)
      Array(self["ignored"][dependency["type"]]).any? do |pattern|
        File.fnmatch?(pattern, dependency["name"], File::FNM_PATHNAME | File::FNM_CASEFOLD)
      end
    end

    # Is the license of the dependency allowed?
    def allowed?(license)
      Array(self["allowed"]).include?(license)
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

    # Returns the cache path for the application based on:
    # 1. An explicitly set cache path for the application, if set
    # 2. An inherited shared cache path
    # 3. An inherited cache path joined with the app name if not shared
    # 4. The default cache path joined with the app name
    def detect_cache_path(options, inherited_options)
      return options["cache_path"] unless options["cache_path"].to_s.empty?

      # if cache_path and shared_cache are both set in inherited_options,
      # don't append the app name to the cache path
      cache_path = inherited_options["cache_path"]
      return cache_path if cache_path && inherited_options["shared_cache"] == true

      cache_path ||= DEFAULT_CACHE_PATH
      File.join(cache_path, self["name"])
    end

    def verify_arg(property)
      return if self[property]
      raise Licensed::Configuration::LoadError,
        "App #{self["name"]} is missing required property #{property}"
    end

    # Returns a name for the application as one of:
    # 1. An explicitly configured app name, if set
    # 2. A generated app name based on an configured "name" options hash
    # 3. A default value - the source_path directory name
    def generate_app_name
      # use default_app_name if a name value is not set
      return source_path_directory_app_name if self["name"].to_s.empty?
      # keep the same name value unless a hash is given with naming options
      return self["name"] unless self["name"].is_a?(Hash)

      generator = self.dig("name", "generator")
      case generator
      when nil, DIRECTORY_NAME_GENERATOR_KEY
        source_path_directory_app_name
      when RELATIVE_PATH_GENERATOR_KEY
        relative_path_app_name
      else
        raise Licensed::Configuration::LoadError,
          "Invalid value configured for name.generator: #{generator}.  Value must be one of #{ALL_NAME_GENERATOR_KEYS.join(",")}"
      end
    end

    # Returns an app name from the directory name of the configured source path
    def source_path_directory_app_name
      File.basename(self["source_path"])
    end

    # Returns an app name from the relative path from the configured app root
    # to the configured app source path.
    def relative_path_app_name
      source_path_parts = File.expand_path(self["source_path"]).split("/")
      root_path_parts = File.expand_path(self["root"]).split("/")

      # if the source path is equivalent to the root path,
      # return the root directory name
      return root_path_parts[-1] if source_path_parts == root_path_parts

      if source_path_parts[0..root_path_parts.size-1] != root_path_parts
        raise Licensed::Configuration::LoadError,
          "source_path must be a descendent of the app root to generate an app name from the relative source_path"
      end

      name_parts = source_path_parts[root_path_parts.size..-1]

      separator = self.dig("name", "separator") || DEFAULT_RELATIVE_PATH_NAME_SEPARATOR
      depth = self.dig("name", "depth") || 0
      if depth < 0
        raise Licensed::Configuration::LoadError, "name.depth configuration value cannot be less than -1"
      end

      # offset the depth value by -1 to work as an offset from the end of the array
      # 0 becomes -1, with a start index of (-1 - -1) = 0, or the full array
      # 1 becomes 0, with a start index of (-1 - 0) = -1, or only the last element
      # and so on...
      depth = depth - 1
      start_index = depth >= name_parts.length ? 0 : -1 - depth
      name_parts[start_index..-1].join(separator)
    end
  end

  class Configuration
    DEFAULT_CONFIG_FILES = [
      ".licensed.yml".freeze,
      ".licensed.yaml".freeze,
      ".licensed.json".freeze
    ].freeze

    class LoadError < StandardError; end

    # An array of the applications in this licensed configuration.
    attr_reader :apps

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
      apps << default_options.merge(options) if apps.empty?

      # apply a root setting to all app configurations so that it's available
      # when expanding app source paths
      apps.each { |app| app["root"] ||= options["root"] if options["root"] }

      apps = apps.flat_map { |app| self.class.expand_app_source_path(app) }
      @apps = apps.map { |app| AppConfiguration.new(app, options) }
    end

    private

    def self.expand_app_source_path(app_config)
      # map a source_path configuration value to an array of non-empty values
      source_path_array = Array(app_config["source_path"])
                            .reject { |path| path.to_s.empty? }
                            .compact
      app_root = AppConfiguration.root_for(app_config)
      return app_config.merge("source_path" => app_root) if source_path_array.empty?

      # check if the source path maps to an existing directory
      if source_path_array.length == 1
        source_path = File.expand_path(source_path_array[0], app_root)
        return app_config.merge("source_path" => source_path) if Dir.exist?(source_path)
      end

      # try to expand the source path for glob patterns
      expanded_source_paths = source_path_array.reduce(Set.new) do |matched_paths, pattern|
        current_matched_paths = if pattern.start_with?("!")
          # if the pattern is an exclusion, remove all matching files
          # from the result
          matched_paths - Dir.glob(pattern[1..-1])
        else
          # if the pattern is an inclusion, add all matching files
          # to the result
          matched_paths + Dir.glob(pattern)
        end

        current_matched_paths.select { |p| File.directory?(p) }
      end

      configs = expanded_source_paths.map { |path| app_config.merge("source_path" => path) }

      # if no directories are found for the source path, return the original config
      if configs.size == 0
        app_config["source_path"] = app_root if app_config["source_path"].is_a?(Array)
        return app_config
      end

      # update configured values for name and cache_path for uniqueness.
      # this is only needed when values are explicitly set, AppConfiguration
      # will handle configurations that don't have these explicitly set
      configs.each do |config|
        dir_name = File.basename(config["source_path"])
        config["name"] = "#{config["name"]}-#{dir_name}" if config["name"].is_a?(String)

        # if a cache_path is set and is not marked as shared, append the app name
        # to the end of the cache path to make a unique cache path for the app
        if config["cache_path"] && config["shared_cache"] != true
          config["cache_path"] = File.join(config["cache_path"], dir_name)
        end
      end

      configs
    end

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
        "cache_path" => AppConfiguration::DEFAULT_CACHE_PATH
      }
    end
  end
end
