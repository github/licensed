# frozen_string_literal: true
require "json"
require "pathname"
require "licensed/sources/helpers/content_versioning"

module Licensed
  module Sources
    class Go < Source
      include Licensed::Sources::ContentVersioning

      def enabled?
        Licensed::Shell.tool_available?("go") && go_source?
      end

      def enumerate_dependencies
        with_configured_gopath do
          packages.map do |package|
            import_path = non_vendored_import_path(package["ImportPath"])
            error = package.dig("Error", "Err") if package["Error"]
            package_dir = package["Dir"]

            Dependency.new(
              name: import_path,
              version: package_version(package),
              path: package_dir,
              search_root: search_root(package_dir),
              errors: Array(error),
              metadata: {
                "type"        => Go.type,
                "summary"     => package["Doc"],
                "homepage"    => homepage(import_path)
              }
            )
          end
        end
      end

      # Returns an array of dependency package import paths
      def packages
        dependency_packages = if go_version < Gem::Version.new("1.11.0")
          root_package_deps
        else
          go_list_deps
        end

        # don't include go std packages
        # don't include packages under the root project that aren't vendored
        dependency_packages
          .reject { |pkg| go_std_package?(pkg) }
          .reject { |pkg| local_package?(pkg) }
      end

      # Returns non-ignored packages found from the root packages "Deps" property
      def root_package_deps
        # check for ignored packages to avoid raising errors calling `go list`
        # when ignored package is not found
        Array(root_package["Deps"]).map { |name| package_info(name) }
      end

      # Returns the list of dependencies as returned by "go list -json -deps"
      # available in go 1.11
      def go_list_deps
        # the CLI command returns packages in a pretty-printed JSON format but
        # not separated by commas. this gsub adds commas after all non-indented
        # "}" that close root level objects.
        # (?!\z) uses negative lookahead to not match the final "}"
        deps = package_info_command("-deps").gsub(/^}(?!\z)$/m, "},")
        JSON.parse("[#{deps}]")
      end

      # Returns whether the given package import path belongs to the
      # go std library or not
      #
      # package - package to check as part of the go standard library
      def go_std_package?(package)
        return false unless package
        return true if package["Standard"]

        import_path = package["ImportPath"]
        return false unless import_path

        # modify the import path to look like the import path `go list` returns for vendored std packages
        std_vendor_import_path = import_path.sub(%r{^#{root_package["ImportPath"]}/vendor/golang.org}, "vendor/golang_org")
        go_std_packages.include?(import_path) || go_std_packages.include?(std_vendor_import_path)
      end

      # Returns whether the package is local to the current project
      def local_package?(package)
        return false unless package && package["ImportPath"]
        import_path = package["ImportPath"]
        import_path.start_with?(root_package["ImportPath"]) && !vendored_path?(import_path)
      end

      # Returns the version for a given package
      #
      # package - package to get version of
      def package_version(package)
        # use module version if it exists
        go_mod = package["Module"]
        return go_mod["Version"] if go_mod

        package_directory = package["Dir"]
        return unless package_directory

        # find most recent git SHA for a package, or nil if SHA is
        # not available
        Dir.chdir package_directory do
          contents_version *contents_version_arguments
        end
      end

      # Determines the arguments to pass to contents_version based on which
      # version strategy is selected
      #
      # Returns an array of arguments to pass to contents version
      def contents_version_arguments
        if version_strategy == Licensed::Sources::ContentVersioning::GIT
          ["."]
        else
          Dir["*"]
        end
      end

      # Returns the homepage for a package import_path.  Assumes that the
      # import path itself is a url domain and path
      def homepage(import_path)
        return unless import_path

        # hacky but generally works due to go packages looking like
        # "github.com/..." or "golang.org/..."
        "https://#{import_path}"
      end

      # Returns the root directory to search for a package license
      #
      # package - package object obtained from package_info
      def search_root(package_dir)
        return nil if package_dir.nil? || package_dir.empty?

        # search root choices:
        # 1. vendor folder if package is vendored
        # 2. GOPATH
        # 3. nil (no search up directory hierarchy)
        return package_dir.match("^(.*/vendor)/.*$")[1] if vendored_path?(package_dir)
        gopath
      end

      # Returns whether a package is vendored or not based on the package
      # import_path
      #
      # path - Package path to test
      def vendored_path?(path)
        path && path.include?("vendor/")
      end

      # Returns the import path parameter without the vendor component
      #
      # import_path - Package import path with vendor component
      def non_vendored_import_path(import_path)
        return unless import_path
        return import_path unless vendored_path?(import_path)
        import_path.split("vendor/")[1]
      end

      # Returns a hash of information about the package with a given import path
      #
      # import_path - Go package import path
      def package_info(import_path)
        JSON.parse(package_info_command(import_path))
      end

      # Returns package information as a JSON string
      #
      # args - additional arguments to `go list`, e.g. Go package import path
      def package_info_command(*args)
        Licensed::Shell.execute("go", "list", "-e", "-json", *Array(args)).strip
      end

      # Returns the info for the package under test
      def root_package
        @root_package ||= package_info(".")
      end

      # Returns whether go source is found
      def go_source?
        with_configured_gopath { Licensed::Shell.success?("go", "doc") }
      end

      # Returns a list of go standard packages
      def go_std_packages
        @std_packages ||= Licensed::Shell.execute("go", "list", "std").lines.map(&:strip)
      end

      # Returns a GOPATH value from either a configuration value or ENV["GOPATH"],
      # with the configuration value preferred over the ENV var
      def gopath
        return @gopath if defined?(@gopath)

        path = @config.dig("go", "GOPATH")
        @gopath = if path.nil? || path.empty?
                    ENV["GOPATH"]
                  else
                    root = begin
                             @config.root
                           rescue Licensed::Shell::Error
                             Pathname.pwd
                           end
                    File.expand_path(path, root)
                  end
      end

      # Returns the current version of go available, as a Gem::Version
      def go_version
        @go_version ||= begin
          full_version = Licensed::Shell.execute("go", "version").strip
          version_string = full_version.gsub(%r{.*go(\d+\.\d+(\.\d+)?).*}, "\\1")
          Gem::Version.new(version_string)
        end
      end

      private

      # Execute a block with ENV["GOPATH"] set to the value of #gopath.
      # Any pre-existing ENV["GOPATH"] value is restored after the block ends.
      def with_configured_gopath(&block)
        begin
          original_gopath = ENV["GOPATH"]
          ENV["GOPATH"] = gopath

          block.call
        ensure
          ENV["GOPATH"] = original_gopath
        end
      end
    end
  end
end
