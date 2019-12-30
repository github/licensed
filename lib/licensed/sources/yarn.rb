# frozen_string_literal: true
require "json"

module Licensed
  module Sources
    class Yarn < Source
      def enabled?
        return unless Licensed::Shell.tool_available?("yarn") && Licensed::Shell.tool_available?("npm")

        config.pwd.join("package.json").exist? && config.pwd.join("yarn.lock").exist?
      end

      def enumerate_dependencies
        packages.map do |name, package|
          Dependency.new(
            name: name,
            version: package["version"],
            path: package["path"],
            metadata: {
              "type"     => Yarn.type,
              "name"     => package["name"],
              "summary"  => package["description"],
              "homepage" => package["homepage"]
            }
          )
        end
      end

      # Finds packages that the current project relies on
      def packages
        return [] if yarn_package_tree.nil?
        all_dependencies = {}
        recursive_dependencies(config.pwd, yarn_package_tree).each do |name, results|
          results.uniq! { |package| package["version"] }
          if results.size == 1
            # if there is only one package for a name, reference it by name
            all_dependencies[name] = results[0]
          else
            # if there is more than one package for a name, reference each by
            # "<name>-<version>"
            results.each do |package|
              all_dependencies[package["id"].sub("@", "-")] = package
            end
          end
        end

        # yarn info is a slow operation - run it in parallel for all dependencies.
        # afterwards parse and merge the returned data serially, JSON.parse
        # might not be thread safe
        Parallel.map(all_dependencies) { |name, dep| [name, dep, yarn_info_command(dep["id"])] }
                .map { |(name, dep, info)| [name, merge_yarn_info(dep, info)] }
                .to_h
      end

      # Recursively parse dependency JSON data.  Returns a hash mapping the
      # package name to it's metadata
      def recursive_dependencies(path, dependencies, result = {})
        dependencies.each do |dependency|
          next if dependency["shadow"]
          name, version = dependency["name"].split("@")

          dependency_path = path.join("node_modules", name)
          (result[name] ||= []) << {
            "id" => dependency["name"],
            "name" => name,
            "version" => version,
            "path" => dependency_path
          }
          recursive_dependencies(dependency_path, dependency["children"], result)
        end
        result
      end

      # Finds and returns the yarn package tree listing from `yarn list` output
      def yarn_package_tree
        return @yarn_package_tree if defined?(@yarn_package_tree)
        @yarn_package_tree = begin
          # parse all lines of output to json and find one that is "type": "tree"
          tree = yarn_list_command.lines
                                  .map(&:strip)
                                  .map(&JSON.method(:parse))
                                  .find { |json| json["type"] == "tree" }
          tree&.dig("data", "trees")
        end
      end

      # Returns the output from running `yarn list` to get project dependencies
      def yarn_list_command
        args = %w(--json -s --no-progress)
        args << "--production" unless include_non_production?
        Licensed::Shell.execute("yarn", "list", *args, allow_failure: true)
      end

      # Returns a combination of tree data from `yarn list` and results of
      # the ouput from `yarn info`
      def merge_yarn_info(tree_data, yarn_info)
        return tree_data if yarn_info.nil?

        yarn_info = yarn_info.lines
                             .map(&:strip)
                             .map(&JSON.method(:parse))
                             .find { |json| json["type"] == "inspect" }
        return tree_data if yarn_info.nil?

        tree_data.merge(yarn_info["data"])
      end

      # Returns the output from running `yarn info` to get package info
      def yarn_info_command(id)
        Licensed::Shell.execute("yarn", "info", "-s", "--json", id, allow_failure: true)
      end

      # Returns whether to include non production dependencies based on the licensed configuration settings
      def include_non_production?
        config.dig("yarn", "production_only") == false
      end
    end
  end
end
