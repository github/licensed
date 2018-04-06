# frozen_string_literal: true
require "bundler"

module Licensed
  module Source
    class Bundler
      GEMFILES = %w{Gemfile gems.rb}.freeze

      def initialize(config)
        @config = config
      end

      def enabled?
        @config.enabled?(type) && lockfile_path && lockfile_path.exist?
      end

      def type
        "rubygem"
      end

      def dependencies
        @dependencies ||= with_local_configuration do
          definition.specs_for(groups).map do |spec|
            Dependency.new(spec.gem_dir, {
              "type"     => type,
              "name"     => spec.name,
              "version"  => spec.version.to_s,
              "summary"  => spec.summary,
              "homepage" => spec.homepage
            })
          end
        end
      end

      # Build the bundler definition
      def definition
        @definition ||= ::Bundler::Definition.build(gemfile_path, lockfile_path, nil)
      end

      # Returns the bundle definition groups, excluding test and development
      def groups
        definition.groups - [:test, :development]
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

      private

      # helper to clear all bundler environment around a yielded block
      def with_local_configuration
        original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]

        # with a clean, original environment
        ::Bundler.with_original_env do
          # force bundler to use the local gem file
          ENV["BUNDLE_GEMFILE"] = gemfile_path.to_s

          # reset all bundler configuration
          ::Bundler.reset!
          # and re-configure with settings for current directory
          ::Bundler.configure

          yield
        end
      ensure
        ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile
        # restore bundler configuration
        ::Bundler.reset!
        ::Bundler.configure
      end
    end
  end
end
