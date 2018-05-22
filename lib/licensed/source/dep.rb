# frozen_string_literal: true
require "tomlrb"

module Licensed
  module Source
    class Dep
      def initialize(config)
        @config = config
      end

      def type
        "dep"
      end

      def enabled?
        @config.enabled?(type) && go_dep_available?
      end

      def dependencies
        @dependencies ||= begin
          packages.map do |package|
            package_dir = @config.pwd.join("vendor", package[:name])
            search_root = @config.pwd.join("vendor", package[:project])

            unless package_dir.exist?
              next if @config.ignored?("type" => type, "name" => package[:name])
              raise "couldn't find package for #{package[:name]}"
            end

            Dependency.new(package_dir.to_s, {
              "type"        => type,
              "name"        => package[:name],
              "homepage"    => "https://#{package[:name]}",
              "search_root" => search_root.to_s,
              "version"     => package[:version]
            })
          end
        end
      end

      # Returns an array of dependency packages specified from Gopkg.lock
      def packages
        gopkg_lock = Tomlrb.load_file(gopkg_lock_path, symbolize_keys: true)
        return [] unless gopkg_lock && gopkg_lock[:projects]

        gopkg_lock[:projects].flat_map do |project|
          # map each package to a full import path
          # then return a hash for each import path containing the path and the version
          project[:packages].map { |package| package == "." ? project[:name] : "#{project[:name]}/#{package}" }
                            .reject { |import_path| go_std_package?(import_path) }
                            .map { |import_path| { name: import_path, version: project[:revision], project: project[:name] } }
        end
      end

      # Returns whether the package is part of the go std list.  Replaces
      # "golang.org" with "golang_org" to match packages listed in `go list std`
      # as "vendor/golang_org/*" but are vendored as "vendor/golang.org/*"
      def go_std_package?(import_path)
        go_std_packages.include? "vendor/#{import_path.sub(/^golang.org/, "golang_org")}"
      end

      def go_dep_available?
        return false unless gopkg_lock_path.exist? && gopkg_toml_path.exist?
        return true if @config.dig("dep", "allow_ignored") == true

        gopkg_toml = Tomlrb.load_file(gopkg_toml_path, symbolize_keys: true)
        gopkg_toml[:ignored].nil? || gopkg_toml[:ignored].empty?
      end

      def gopkg_lock_path
        @config.pwd.join("Gopkg.lock")
      end

      def gopkg_toml_path
        @config.pwd.join("Gopkg.toml")
      end

      # Returns a list of go standard packages
      def go_std_packages
        @std_packages ||= begin
          return [] unless Licensed::Shell.tool_available?("go")
          Licensed::Shell.execute("go", "list", "std").lines.map(&:strip)
        end
      end
    end
  end
end
