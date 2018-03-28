# frozen_string_literal: true
require "English"

module Licensed
  module Source
    class Cabal
      def initialize(config)
        @config = config
      end

      def type
        "cabal"
      end

      def enabled?
        @config.enabled?(type) && cabal_packages.any? && ghc?
      end

      def dependencies
        @dependencies ||= package_ids.map do |id|
          package = package_info(id)

          path, search_root = package_docs_dirs(package)
          Dependency.new(path, {
            "type"     => type,
            "name"     => package["name"],
            "version"  => package["version"],
            "summary"  => package["synopsis"],
            "homepage" => safe_homepage(package["homepage"]),
            "search_root" => search_root
          })
        end
      end

      # Returns the packages document directory and search root directory
      # as an array
      def package_docs_dirs(package)
        unless package["haddock-html"]
          # default to a local vendor directory if haddock-html property
          # isn't available
          return [File.join(@config.pwd, "vendor", package["name"]), nil]
        end

        html_dir = package["haddock-html"]
        data_dir = package["data-dir"]
        return [html_dir, nil] unless data_dir

        # only allow data directories that are ancestors of the html directory
        unless Pathname.new(html_dir).fnmatch?(File.join(data_dir, "**"))
          data_dir = nil
        end

        [html_dir, data_dir]
      end

      # Returns a homepage url that enforces https and removes url fragments
      def safe_homepage(homepage)
        return unless homepage
        # use https and remove url fragment
        homepage.gsub(/http:/, "https:")
                .gsub(/#[^?]*\z/, "")
      end

      # Returns a `Set` of the package ids for all cabal dependencies
      def package_ids
        deps = cabal_packages.flat_map { |n| package_dependencies(n, false) }
        recursive_dependencies(deps)
      end

      # Recursively finds the dependencies for each cabal package.
      # Returns a `Set` containing the package names for all dependencies
      def recursive_dependencies(package_names, results = Set.new)
        return [] if package_names.nil? || package_names.empty?

        new_packages = Set.new(package_names) - results.to_a
        return [] if new_packages.empty?

        results.merge new_packages

        dependencies = new_packages.flat_map { |n| package_dependencies(n) }
                                   .compact

        return results if dependencies.empty?

        results.merge recursive_dependencies(dependencies, results)
      end

      # Returns an array of dependency package names for the cabal package
      # given by `id`
      def package_dependencies(id, full_id = true)
        package_dependencies_command(id, full_id).gsub("depends:", "")
                                                 .split
                                                 .map(&:strip)
      end

      # Returns the output of running `ghc-pkg field depends` for a package id
      # Optionally allows for interpreting the given id as an
      # installed package id (`--ipid`)
      def package_dependencies_command(id, full_id)
        fields = %w(depends)

        if full_id
          ghc_pkg_field_command(id, fields, "--ipid")
        else
          ghc_pkg_field_command(id, fields)
        end
      end

      # Returns package information as a hash for the given id
      def package_info(id)
        package_info_command(id).lines.each_with_object({}) do |line, info|
          key, value = line.split(":", 2).map(&:strip)
          next unless key && value

          info[key] = value
        end
      end

      # Returns the output of running `ghc-pkg field` to obtain package information
      def package_info_command(id)
        fields = %w(name version synopsis homepage haddock-html data-dir)
        ghc_pkg_field_command(id, fields, "--ipid")
      end

      # Runs a `ghc-pkg field` command for a given set of fields and arguments
      # Automatically includes ghc package DB locations in the command
      def ghc_pkg_field_command(id, fields, *args)
        Licensed::Shell.execute("ghc-pkg", "field", id, fields.join(","), *args, *package_db_args)
      end

      # Returns an array of ghc package DB locations as specified in the app
      # configuration
      def package_db_args
        return [] unless @config["cabal"]
        Array(@config["cabal"]["ghc_package_db"]).map do |path|
          next "--#{path}" if %w(global user).include?(path)
          path = realized_ghc_package_path(path)
          path = File.expand_path(path, Licensed::Git.repository_root)

          next unless File.exist?(path)
          "--package-db=#{path}"
        end.compact
      end

      # Returns a ghc package path with template markers replaced by live
      # data
      def realized_ghc_package_path(path)
        path.gsub("<ghc_version>", ghc_version)
      end

      # Return an array of the top-level cabal packages for the current app
      def cabal_packages
        cabal_files.map do |f|
          name_match = File.read(f).match(/^name:\s*(.*)$/)
          name_match[1] if name_match
        end.compact
      end

      # Returns an array of the local directory cabal package files
      def cabal_files
        @cabal_files ||= Dir.glob(File.join(@config.pwd, "*.cabal"))
      end

      # Returns the ghc cli tool version
      def ghc_version
        return unless ghc?
        @version ||= Licensed::Shell.execute("ghc", "--numeric-version")
      end

      # Returns whether the ghc cli tool is available
      def ghc?
        @ghc ||= Licensed::Shell.tool_available?("ghc")
      end
    end
  end
end
