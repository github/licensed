# frozen_string_literal: true
module Licensed
  module Matchers
    class Wildcard
      def initialize(wildcard_string)
        @wildcard_regexp = build_regexp(wildcard_string)
      end

      def match?(value)
        @wildcard_regexp.match? value
      end

      private

      def build_regexp(wildcard_string)
        escaped_regexp = Regexp.escape(wildcard_string).gsub('\*', ".+")
        Regexp.new "\\A#{escaped_regexp}\\z"
      end
    end
  end
end
