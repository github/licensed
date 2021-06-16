# frozen_string_literal: true
require "delegate"
begin
  require "bundler"
  require "licensed/sources/bundler/missing_specification"
rescue LoadError
end

module Licensed
  module Sources
    class Bundler < Source
      class Dependency < Licensed::Dependency
        attr_reader :loaded_from

        def initialize(name:, version:, path:, loaded_from:, errors: [], metadata: {})
          @loaded_from = loaded_from
          super name: name, version: version, path: path, errors: errors, metadata: metadata
        end

        # Load a package manager file from the base Licensee::Projects::FsProject
        # or from a gem specification file.
        def package_file
          super || spec_file
        end

        private

        # Find a package manager file from the given bundler specification's
        # `loaded_from` if available.
        def spec_file
          return @spec_file if defined?(@spec_file)
          return @spec_file = nil unless loaded_from && File.exist?(loaded_from)
          @spec_file = begin
            file = { name: File.basename(loaded_from), dir: File.dirname(loaded_from) }
            Licensee::ProjectFiles::PackageManagerFile.new(File.read(loaded_from), file)
          end
        end
      end

      GEMFILES = { "Gemfile" => "Gemfile.lock", "gems.rb" => "gems.locked" }
      DEFAULT_WITHOUT_GROUPS = %i{development test}
      RUBY_PACKER_ERROR = "The bundler source cannot be used from the executable built with ruby-packer.  Please install licensed using `gem install` or using bundler."

      def enabled?
        # running a ruby-packer-built licensed exe when ruby isn't available
        # could lead to errors if the host ruby doesn't exist
        return false if ruby_packer? && !Licensed::Shell.tool_available?("ruby")
        defined?(::Bundler) && lockfile_path && lockfile_path.exist?
      end

      def enumerate_dependencies
        raise Licensed::Sources::Source::Error.new(RUBY_PACKER_ERROR) if ruby_packer?

        with_local_configuration do
          specs.map do |spec|
            next if spec.name == "bundler" && !include_bundler?
            next if spec.name == config["name"]

            error = spec.error if spec.respond_to?(:error)
            Dependency.new(
              name: spec.name,
              version: spec.version.to_s,
              path: spec.full_gem_path,
              loaded_from: spec.loaded_from,
              errors: Array(error),
              metadata: {
                "type"     => Bundler.type,
                "summary"  => spec.summary,
                "homepage" => spec.homepage
              }
            )
          end
        end
      end

      # Returns an array of Gem::Specifications for all gem dependencies
      def specs
        @specs ||= definition.specs_for(groups)
      end

      # Returns whether to include bundler as a listed dependency of the project
      def include_bundler?
        @include_bundler ||= begin
          # include if bundler is listed as a direct dependency that should be included
          requested_dependencies = definition.dependencies.select { |d| (d.groups & groups).any? && d.should_include? }
          return true if requested_dependencies.any? { |d| d.name == "bundler" }
          # include if bundler is an indirect dependency
          return true if specs.flat_map(&:dependencies).any? { |d| d.name == "bundler" }
          false
        end
      end

      # Build the bundler definition
      def definition
        @definition ||= ::Bundler::Definition.build(gemfile_path, lockfile_path, nil)
      end

      # Returns the bundle definition groups, removing "without" groups,
      # and including "with" groups
      def groups
        @groups ||= definition.groups - bundler_setting_array(:without) + bundler_setting_array(:with) - exclude_groups
      end

      # Returns a bundler setting as an array.
      # Depending on the version of bundler, array values are either returned as
      # a raw string ("a:b:c") or as an array ([:a, :b, :c])
      def bundler_setting_array(key)
        setting = ::Bundler.settings[key]
        setting = setting.split(":").map(&:to_sym) if setting.is_a?(String)
        Array(setting)
      end

      # Returns any groups to exclude specified from both licensed configuration
      # and bundler configuration.
      # Defaults to [:development, :test] + ::Bundler.settings[:without]
      def exclude_groups
        @exclude_groups ||= begin
          exclude = Array(config.dig("bundler", "without"))
          exclude = DEFAULT_WITHOUT_GROUPS if exclude.empty?
          exclude.uniq.map(&:to_sym)
        end
      end

      # Returns the path to the Bundler Gemfile
      def gemfile_path
        @gemfile_path ||= GEMFILES.keys
                                  .map { |g| config.pwd.join g }
                                  .find { |f| f.exist? }
      end

      # Returns the path to the Bundler Gemfile.lock
      def lockfile_path
        return unless gemfile_path
        @lockfile_path ||= gemfile_path.dirname.join(GEMFILES[gemfile_path.basename.to_s])
      end

      # helper to clear all bundler environment around a yielded block
      def with_local_configuration
        # silence any bundler warnings while running licensed
        bundler_ui, ::Bundler.ui = ::Bundler.ui, ::Bundler::UI::Silent.new

        original_bundle_gemfile = nil
        if gemfile_path.to_s != ENV["BUNDLE_GEMFILE"]
          # force bundler to use the local gem file
          original_bundle_gemfile, ENV["BUNDLE_GEMFILE"] = ENV["BUNDLE_GEMFILE"], gemfile_path.to_s

          # reset all bundler configuration
          ::Bundler.reset!
          # and re-configure with settings for current directory
          ::Bundler.configure
        end

        yield
      ensure
        if original_bundle_gemfile
          ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile

          # restore bundler configuration
          ::Bundler.reset!
          ::Bundler.configure
        end

        ::Bundler.ui = bundler_ui
      end

      # Returns whether the current licensed execution is running ruby-packer
      def ruby_packer?
        @ruby_packer ||= RbConfig::TOPDIR =~ /__enclose_io_memfs__/
      end
    end
  end
end
