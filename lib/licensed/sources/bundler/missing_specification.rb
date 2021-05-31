# frozen_string_literal: true

require "bundler/match_platform"

# Bundler normally raises a "GemNotFound" error when a specification
# can't be materialized which halts bundler dependency enumeration.

# This monkey patch instead creates MissingSpecification objects to
# identify missing specs without raising errors and halting enumeration.
# It was the most minimal-touch solution I could think of that should reliably
# work across many bundler versions

module Licensed
  module Bundler
    class MissingSpecification < Gem::BasicSpecification
      include ::Bundler::MatchPlatform

      attr_reader :name, :version, :platform, :source
      def initialize(name:, version:, platform:, source:)
        @name = name
        @version = version
        @platform = platform
        @source = source
      end

      def dependencies
        []
      end

      def gem_dir; end
      def gems_dir
        Gem.dir
      end
      def summary; end
      def homepage; end

      def error
        "could not find #{name} (#{version}) in any sources"
      end
    end
  end
end

module Bundler
  class LazySpecification
    alias_method :orig_materialize, :__materialize__
    def __materialize__
      spec = orig_materialize
      return spec if spec

      Licensed::Bundler::MissingSpecification.new(name: name, version: version, platform: platform, source: source)
    end
  end
end
