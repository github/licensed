# frozen_string_literal: true
require "json"

module Licensed
  module Source
    class NPM
      def self.type
        "npm"
      end

      def initialize(config)
        @config = config
      end

      def enabled?
        Licensed::Shell.tool_available?("npm") && File.exist?(@config.pwd.join("package.json"))
      end

      def dependencies
        return @dependencies if defined?(@dependencies)

        locations = {}
        package_location_command.lines.each do |line|
          path, id = line.split(":")[0, 2]
          locations[id] ||= path
        end

        packages = recursive_dependencies(JSON.parse(package_metadata_command)["dependencies"])

        @dependencies = packages.map do |name, package|
          path = package["realPath"] || locations["#{package["name"]}@#{package["version"]}"]
          fail "couldn't locate #{name} under node_modules/" unless path
          Dependency.new(path, {
            "type"     => NPM.type,
            "name"     => package["name"],
            "version"  => package["version"],
            "summary"  => package["description"],
            "homepage" => package["homepage"]
          })
        end
      end

      # Recursively parse dependency JSON data.  Returns a hash mapping the
      # package name to it's metadata
      def recursive_dependencies(dependencies, result = {})
        dependencies.each do |name, dependency|
          (result[name] ||= {}).update(dependency)
          recursive_dependencies(dependency["dependencies"] || {}, result)
        end
        result
      end

      # Returns the output from running `npm list` to get package paths
      def package_location_command
        npm_list_command("--parseable", "--production", "--long")
      end

      # Returns the output from running `npm list` to get package metadata
      def package_metadata_command
        npm_list_command("--json", "--production", "--long")
      end

      # Executes an `npm list` command with the provided args and returns the
      # output from stdout
      def npm_list_command(*args)
        Licensed::Shell.execute("npm", "list", *args)
      end
    end
  end
end
