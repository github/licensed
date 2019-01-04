# frozen_string_literal: true
begin
  require "bundler"
rescue LoadError
end

module Licensed
  module Sources
    class Bundler < Source
      GEMFILES = %w{Gemfile gems.rb}.freeze
      DEFAULT_WITHOUT_GROUPS = %i{development test}

      def enabled?
        defined?(::Bundler) && lockfile_path && lockfile_path.exist?
      end

      def enumerate_dependencies
        with_local_configuration do
          specs.map do |spec|
            Licensed::Dependency.new(
              name: spec.name,
              version: spec.version.to_s,
              path: spec.gem_dir,
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

      # Returns the specs for dependencies that pass the checks in `include?`
      # Raises an error if the specification isn't found
      def specs_for_dependencies(dependencies, source)
        included_dependencies = dependencies.select { |d| include?(d, source) }
        included_dependencies.map do |dep|
          gem_spec(dep) || raise("Unable to find a specification for #{dep.name} (#{dep.requirement}) in any sources")
        end
      end

      # Returns a Gem::Specification for the provided gem argument.  If a
      # Gem::Specification isn't found, an error will be raised.
      def gem_spec(dependency)
        return unless dependency

        # find a specifiction from the resolved ::Bundler::Definition specs
        spec = definition.resolve.find { |s| s.satisfies?(dependency) }

        # a nil spec should be rare, generally only seen from bundler
        return bundle_exec_gem_spec(dependency.name) if spec.nil?

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
        bundle_exec_gem_spec(dependency.name)
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
      def bundle_exec_gem_spec(name)
        # `gem` must be available to run `gem specification`
        return unless Licensed::Shell.tool_available?("gem")

        # use `gem specification` with a clean ENV to get gem specification YAML
        yaml = ::Bundler.with_original_env { Licensed::Shell.execute(*ruby_command_args("gem", "specification", name)) }
        Gem::Specification.from_yaml(yaml)
      end

      # Build the bundler definition
      def definition
        @definition ||= ::Bundler::Definition.build(gemfile_path, lockfile_path, nil)
      end

      # Returns the bundle definition groups, removing "without" groups,
      # and including "with" groups
      def groups
        definition.groups - Array(::Bundler.settings[:without]) + Array(::Bundler.settings[:with]) - exclude_groups
      end

      # Returns any groups to exclude specified from both licensed configuration
      # and bundler configuration.
      # Defaults to [:development, :test] + ::Bundler.settings[:without]
      def exclude_groups
        @exclude_groups ||= begin
          exclude = Array(@config.dig("bundler", "without"))
          exclude = DEFAULT_WITHOUT_GROUPS if exclude.empty?
          exclude.uniq.map(&:to_sym)
        end
      end

      # Returns the path to the Bundler Gemfile
      def gemfile_path
        @gemfile_path ||= GEMFILES.map { |g| @config.pwd.join g }
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
          exe = @config.dig("bundler", "bundler_exe")
          return "bundle" unless exe
          return exe if Licensed::Shell.tool_available?(exe)
          @config.root.join(exe)
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

          if Licensed::Shell.tool_available?("ruby")
            # set the ruby version in Gem::ConfigMap to the ruby version from the host.
            # this helps Bundler find the correct spec sources and paths
            Gem::ConfigMap[:ruby_version] = host_ruby_version
          else
            # running a ruby-packer-built licensed exe when ruby and bundler aren't available
            # is possible but could lead to errors if the host ruby version doesn't
            # match the built executable's ruby version
            @config.ui.warn <<~WARNING
              Ruby wasn't found when enumerating bundler
              dependencies using the licensed executable.  This can cause a
              ruby mismatch between licensed and bundled dependencies and a
              failure to find gem specifications.

              If licensed is unable to find gem specifications that you believe are present,
              please ensure that ruby and bundler are available and try again.
            WARNING
          end
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
