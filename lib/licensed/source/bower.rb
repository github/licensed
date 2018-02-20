# frozen_string_literal: true
require "json"

module Licensed
  module Source
    class Bower
      def initialize(config)
        @config = config
      end

      def type
        "bower"
      end

      def enabled?
        return false unless @config.enabled?(type)

        [@config.pwd.join(".bowerrc"), @config.pwd.join("bower.json")].any? do |path|
          File.exist?(path)
        end
      end

      def dependencies
        @dependencies ||= Dir.glob(bower_path.join("*/.bower.json")).map do |file|
          package = JSON.parse(File.read(file))
          path = bower_path.join(file).dirname.to_path
          Dependency.new(path, {
            "type"     => type,
            "name"     => package["name"],
            "version"  => package["version"] || package["_release"],
            "summary"  => package["description"],
            "homepage" => package["homepage"]
          })
        end
      end

      # Returns a parsed ".bowerrc" configuration, or an empty hash if not found
      def bower_config
        @bower_config ||= begin
          path = @config.pwd.join(".bowerrc")
          path.exist? ? JSON.parse(path.read) : {}
        end
      end

      # Returns the expected path to bower components.
      # Note this does not validate that the returned path is valid
      def bower_path
        pwd = bower_config["cwd"] ? Pathname.new(bower_config["cwd"]).expand_path : @config.pwd
        pwd.join bower_config["directory"] || "bower_components"
      end
    end
  end
end
