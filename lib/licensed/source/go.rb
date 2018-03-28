# frozen_string_literal: true
require "json"
require "English"

module Licensed
  module Source
    class Go
      def initialize(config)
        @config = config
      end

      def type
        "go"
      end

      def enabled?
        @config.enabled?(type) && go_source?
      end

      def dependencies
        @dependencies ||= with_configured_gopath do
          packages.map do |package_name|
            package = package_info(package_name)
            import_path = non_vendored_import_path(package_name)

            if package.empty?
              next if @config.ignored?("type" => type, "name" => package_name)
              raise "couldn't find package for #{import_path}"
            end

            package_dir = package["Dir"]
            Dependency.new(package_dir, {
              "type"        => type,
              "name"        => import_path,
              "summary"     => package["Doc"],
              "homepage"    => homepage(import_path),
              "search_root" => search_root(package_dir),
              "version"     => Licensed::Git.version(package_dir)
            })
          end.compact
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

      # Returns an array of dependency package import paths
      def packages
        return [] unless root_package["Deps"]

        # don't include go std packages
        # don't include packages under the root project that aren't vendored
        root_package["Deps"]
          .uniq
          .select { |d| !go_std_packages.include?(d) }
          .select { |d| !d.start_with?(root_package["ImportPath"]) || vendored_path?(d) }
      end

      # Returns the root directory to search for a package license
      #
      # package - package object obtained from package_info
      def search_root(package_dir)
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

      # Returns package information, or {} if package isn't found
      #
      # package - Go package import path
      def package_info(package = nil)
        info = package_info_command(package)
        return {} if info.empty?
        JSON.parse(info)
      end

      # Returns package information as a JSON string
      #
      # package - Go package import path
      def package_info_command(package)
        package ||= ""
        Licensed::Shell.execute("go", "list", "-json", package)
      end

      # Returns the info for the package under test
      def root_package
        @root_package ||= package_info
      end

      # Returns whether go source is found
      def go_source?
        @go_source ||= with_configured_gopath { Licensed::Shell.success?("go", "doc") }
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
                    File.expand_path(path, Licensed::Git.repository_root)
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
