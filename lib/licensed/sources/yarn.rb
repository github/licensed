# frozen_string_literal: true

module Licensed
  module Sources
    module Yarn
      module ClassMethods
        def type
          "yarn"
        end
      end

      def self.included(klass)
        klass.extend ClassMethods
      end

      def enabled?
        return unless Licensed::Shell.tool_available?("yarn")
        return unless self.class.version_requirement.satisfied_by?(yarn_version)

        config.pwd.join("package.json").exist? && config.pwd.join("yarn.lock").exist?
      end

      def yarn_version
        Gem::Version.new(Licensed::Shell.execute("yarn", "-v"))
      end
    end
  end
end

require "licensed/sources/yarn/v1"
require "licensed/sources/yarn/berry"
