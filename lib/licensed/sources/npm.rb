# frozen_string_literal: true
require "json"

module Licensed
  module Sources
    class NPM < Source
      def self.type
        "npm"
      end

      def enabled?
        Licensed::Shell.tool_available?("npm") && File.exist?(config.pwd.join("package.json"))
      end

      def enumerate_dependencies
        packages.map do |name, package|
          path = package["path"]
          Dependency.new(
            name: name,
            version: package["version"],
            path: path,
            metadata: {
              "type"     => NPM.type,
              "name"     => package["name"],
              "summary"  => package["description"],
              "homepage" => package["homepage"]
            }
          )
        end
      end

      def packages
        root_dependencies = JSON.parse(package_metadata_command)["dependencies"]
        recursive_dependencies(root_dependencies).each_with_object({}) do |(name, results), hsh|
          results.uniq! { |package| package["version"] }
          if results.size == 1
            hsh[name] = results[0]
          else
            results.each do |package|
              name_with_version = "#{name}-#{package["version"]}"
              hsh[name_with_version] = package
            end
          end
        end
      end

      # Recursively parse dependency JSON data.  Returns a hash mapping the
      # package name to it's metadata
      def recursive_dependencies(dependencies, result = {})
        dependencies.each do |name, dependency|
          next if yarn_lock_present && dependency["missing"]
          (result[name] ||= []) << dependency
          recursive_dependencies(dependency["dependencies"] || {}, result)
        end
        result
      end

      # Returns the output from running `npm list` to get package metadata
      def package_metadata_command
        args = %w(--json --long)
        args << "--production" unless include_non_production?
        Licensed::Shell.execute("npm", "list", *args, allow_failure: true)
      end

      # Returns true if a yarn.lock file exists in the current directory
      def yarn_lock_present
        @yarn_lock_present ||= File.exist?(config.pwd.join("yarn.lock"))
      end

      # Returns whether to include non production dependencies based on the licensed configuration settings
      def include_non_production?
        config.dig("npm", "production_only") == false
      end
    end
  end
end
