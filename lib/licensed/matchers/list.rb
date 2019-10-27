# frozen_string_literal: true
module Licensed
  module Matchers
    class List
      def initialize(expressions)
        @list = Array(expressions).map do |expression|
          Factory.call expression
        end
      end

      def include?(name)
        @list.any? { |matcher| matcher.match? name }
      end
    end
  end
end
