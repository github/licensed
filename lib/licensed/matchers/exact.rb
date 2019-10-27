# frozen_string_literal: true
module Licensed
  module Matchers
    class Exact
      def initialize(value)
        @value = value
      end

      def match?(value)
        @value == value
      end
    end
  end
end
