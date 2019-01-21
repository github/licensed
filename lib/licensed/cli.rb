# frozen_string_literal: true
require "licensed"
require "thor"

module Licensed
  class CLI < Thor

    desc "cache", "Cache the licenses of dependencies"
    method_option :force, type: :boolean,
      desc: "Overwrite licenses even if version has not changed."
    method_option :config, aliases: "-c", type: :string,
      desc: "Path to licensed configuration file"
    def cache
      run Licensed::Command::Cache.new(config), force: options[:force]
    end

    desc "status", "Check status of dependencies' cached licenses"
    method_option :config, aliases: "-c", type: :string,
      desc: "Path to licensed configuration file"
    def status
      run Licensed::Command::Status.new(config)
    end

    desc "list", "List dependencies"
    method_option :config, aliases: "-c", type: :string,
      desc: "Path to licensed configuration file"
    def list
      run Licensed::Command::List.new(config)
    end

    map "-v" => :version
    map "--version" => :version
    desc "version", "Show Installed Version of Licensed, [-v, --version]"
    def version
      puts Licensed::VERSION
    end

    # If an error occurs (e.g. a missing command or argument), exit 1.
    def self.exit_on_failure?
      true
    end

    private

    # Returns a configuration object for the CLI command
    def config
      @config ||= Configuration.load_from(config_path)
    end

    # Returns a config path from the CLI if set.
    # Defaults to the current directory if CLI option is not set
    def config_path
      options["config"] || Dir.pwd
    end

    def run(command, *args)
      exit command.run(*args)
    end
  end
end
