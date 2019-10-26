# frozen_string_literal: true
require "delegate"
begin
  require "bundler"
rescue LoadError
end

module Licensed
  module Sources
    class Bundler < Source
      class MissingSpecification < Gem::BasicSpecification
        attr_reader :name, :requirement
        alias_method :version, :requirement
        def initialize(name:, requirement:)
          @name = name
          @requirement = requirement
        end

        def dependencies
          []
        end

        def source
          nil
        end

        def platform; end
        def gem_dir; end
        def gems_dir
          Gem.dir
        end
        def summary; end
        def homepage; end

        def error
          "could not find #{name} (#{requirement}) in any sources"
        end
      end

      class BundlerSpecification < ::SimpleDelegator
        def gem_dir
          dir = super
          return dir if File.exist?(dir)

          File.join(Gem.dir, "gems", full_name)
        end
      end

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

      GEMFILES = %w{Gemfile gems.rb}.freeze
      DEFAULT_WITHOUT_GROUPS = %i{development test}

      def enabled?
        # running a ruby-packer-built licensed exe when ruby isn't available
        # could lead to errors if the host ruby doesn't exist
        return false if ruby_packer? && !Licensed::Shell.tool_available?("ruby")
        defined?(::Bundler) && lockfile_path && lockfile_path.exist?
      end

      def enumerate_dependencies
        with_local_configuration do
          specs.map do |spec|
            error = spec.error if spec.respond_to?(:error)
            Dependency.new(
              name: spec.name,
              version: spec.version.to_s,
              path: spec.gem_dir,
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
        # get the specifications for all dependencies in a Gemfile
        root_dependencies = definition.dependencies.select { |d| include?(d, nil) }
        root_specs = specs_for_dependencies(root_dependencies, nil).compact

        # recursively find the remaining specifications
        all_specs = recursive_specs(root_specs)

        # delete any specifications loaded from a gemspec
        all_specs.delete_if { |s| s.source.is_a?(::Bundler::Source::Gemspec) }
      end

      # Recursively finds the dependencies for Gem specifications.
      # Returns a `Set` containing the package names for all dependencies
      def recursive_specs(specs, results = Set.new)
        return [] if specs.nil? || specs.empty?

        new_specs = Set.new(specs) - results.to_a
        return [] if new_specs.empty?

        results.merge new_specs

        dependency_specs = new_specs.flat_map { |s| specs_for_dependencies(s.dependencies, s.source) }

        return results if dependency_specs.empty?

        results.merge recursive_specs(dependency_specs, results)
      end

      # Returns the specs for dependencies that pass the checks in `include?`.
      # Returns a `MissingSpecification` if a gem specification isn't found.
      def specs_for_dependencies(dependencies, source)
        included_dependencies = dependencies.select { |d| include?(d, source) }
        included_dependencies.map do |dep|
          gem_spec(dep) || MissingSpecification.new(name: dep.name, requirement: dep.requirement)
        end
      end

      # Returns a Gem::Specification for the provided gem argument.
      def gem_spec(dependency)
        return unless dependency

        # find a specifiction from the resolved ::Bundler::Definition specs
        spec = definition.resolve.find { |s| s.satisfies?(dependency) }

        # a nil spec should be rare, generally only seen from bundler
        return matching_spec(dependency) || bundle_exec_gem_spec(dependency.name, dependency.requirement) if spec.nil?

        # try to find a non-lazy specification that matches `spec`
        # spec.source.specs gives access to specifications with more
        # information than spec itself, including platform-specific gems.
        # these objects should have all the information needed to detect license metadata
        source_spec = spec.source.specs.find { |s| s.name == spec.name && s.version == spec.version }
        return source_spec if source_spec

        # look for a specification at the bundler specs path
        spec_path = ::Bundler.specs_path.join("#{spec.full_name}.gemspec")
        return Gem::Specification.load(spec_path.to_s) if File.exist?(spec_path.to_s)

        # if the specification file doesn't exist, get the specification using
        # the bundler and gem CLI
        bundle_exec_gem_spec(dependency.name, dependency.requirement)
      end

      # Returns whether a dependency should be included in the final
      def include?(dependency, source)
        # ::Bundler::Dependency has an extra `should_include?`
        return false unless dependency.should_include? if dependency.respond_to?(:should_include?)

        # Don't return gems added from `add_development_dependency` in a gemspec
        # if the :development group is excluded
        gemspec_source = source.is_a?(::Bundler::Source::Gemspec)
        return false if dependency.type == :development && (!gemspec_source || exclude_development_dependencies?)

        # Gem::Dependency don't have groups - in our usage these objects always
        # come as child-dependencies and are never directly from a Gemfile.
        # We assume that all Gem::Dependencies are ok at this point
        return true if dependency.groups.nil?

        # check if the dependency is in any groups we're interested in
        (dependency.groups & groups).any?
      end

      # Returns whether development dependencies should be excluded
      def exclude_development_dependencies?
        @include_development ||= begin
          # check whether the development dependency group is explicitly removed
          # or added via bundler and licensed configurations
          groups = [:development] - Array(::Bundler.settings[:without]) + Array(::Bundler.settings[:with]) - exclude_groups
          !groups.include?(:development)
        end
      end

      # Load a gem specification from the YAML returned from `gem specification`
      # This is a last resort when licensed can't obtain a specification from other means
      def bundle_exec_gem_spec(name, requirement)
        # `gem` must be available to run `gem specification`
        return unless Licensed::Shell.tool_available?("gem")

        # use `gem specification` with a clean ENV and clean Gem.dir paths
        # to get gem specification at the right directory
        begin
          ::Bundler.with_original_env do
            ::Bundler.rubygems.clear_paths
            yaml = Licensed::Shell.execute(*ruby_command_args("gem", "specification", name, "-v", requirement.to_s))
            spec = Gem::Specification.from_yaml(yaml)
            # this is horrible, but it will cache the gem_dir using the clean env
            # so that it can be used outside of this block when running from
            # the ruby packer executable environment
            spec.gem_dir if ruby_packer?
            spec
          end
        rescue Licensed::Shell::Error
          # return nil
        ensure
          ::Bundler.configure
        end
      end

      # Loads a dependency specification using rubygems' built-in
      # `Dependency#matching_specs` and `Dependency#to_spec`, from the original
      # gem environment
      def matching_spec(dependency)
        begin
          ::Bundler.with_original_env do
            ::Bundler.rubygems.clear_paths
            return unless dependency.matching_specs(true).any?
            BundlerSpecification.new(dependency.to_spec)
          end
        ensure
          ::Bundler.configure
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
        @gemfile_path ||= GEMFILES.map { |g| config.pwd.join g }
                                  .find { |f| f.exist? }
      end

      # Returns the path to the Bundler Gemfile.lock
      def lockfile_path
        return unless gemfile_path
        @lockfile_path ||= gemfile_path.dirname.join("#{gemfile_path.basename}.lock")
      end

      # Returns the configured bundler executable to use, or "bundle" by default.
      def bundler_exe
        @bundler_exe ||= begin
          exe = config.dig("bundler", "bundler_exe")
          return "bundle" unless exe
          return exe if Licensed::Shell.tool_available?(exe)
          config.root.join(exe)
        end
      end

      # Determines if the configured bundler executable is available and returns
      # shell command args with or without `bundle exec` depending on availability.
      def ruby_command_args(*args)
        return Array(args) unless Licensed::Shell.tool_available?(bundler_exe)
        [bundler_exe, "exec", *args]
      end

      private

      # helper to clear all bundler environment around a yielded block
      def with_local_configuration
        # force bundler to use the local gem file
        original_bundle_gemfile, ENV["BUNDLE_GEMFILE"] = ENV["BUNDLE_GEMFILE"], gemfile_path.to_s

        if ruby_packer?
          # if running under ruby-packer, set environment from host

          # hack: setting this ENV var allows licensed to use Gem paths outside
          # of the ruby-packer filesystem.  this is needed to find spec sources
          # from the host filesystem
          ENV["ENCLOSE_IO_RUBYC_1ST_PASS"] = "1"
          ruby_version = Gem::ConfigMap[:ruby_version]
          # set the ruby version in Gem::ConfigMap to the ruby version from the host.
          # this helps Bundler find the correct spec sources and paths
          Gem::ConfigMap[:ruby_version] = host_ruby_version
        end

        # reset all bundler configuration
        ::Bundler.reset!
        # and re-configure with settings for current directory
        ::Bundler.configure

        yield
      ensure
        if ruby_packer?
          # if running under ruby-packer, restore environment after block is finished
          ENV.delete("ENCLOSE_IO_RUBYC_1ST_PASS")
          Gem::ConfigMap[:ruby_version] = ruby_version
        end

        ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile
        # restore bundler configuration
        ::Bundler.reset!
        ::Bundler.configure
      end

      # Returns whether the current licensed execution is running ruby-packer
      def ruby_packer?
        @ruby_packer ||= RbConfig::TOPDIR =~ /__enclose_io_memfs__/
      end

      # Returns the ruby version found in the bundler environment
      def host_ruby_version
        Licensed::Shell.execute(*ruby_command_args("ruby", "-e", "puts Gem::ConfigMap[:ruby_version]"))
      end
    end
  end
end
