# frozen_string_literal: true

module Licensed
  module Sources
    class Source
      class DependencyEnumerationNotImplementedError < StandardError
        def initialize(message = "Source classes must implemented `enumerate_dependencies`")
          super
        end
      end

      class << self
        attr_reader :sources
        def inherited(klass)
          (@sources ||= []) << klass
        end

        def type
          self.name.split(/::/)
                   .last
                   .gsub(/([A-Z\d]+)([A-Z][a-z])/, "\\1_\\2".freeze)
                   .gsub(/([a-z\d])([A-Z])/, "\\1_\\2".freeze)
                   .downcase
        end
      end

      attr_accessor :config

      def initialize(configuration)
        @config = configuration
      end

      def enabled?
        false
      end

      def dependencies
        @dependencies ||= enumerate_dependencies.compact.reject { |d| ignored?(d) }
      end

      def enumerate_dependencies
        raise DependencyEnumerationNotImplementedError
      end

      private

      def ignored?(dependency)
        config.ignored?("type" => self.class.type, "name" => dependency["name"])
      end
    end
  end
end
