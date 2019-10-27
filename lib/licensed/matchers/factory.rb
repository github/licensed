# frozen_string_literal: true
module Licensed
  module Matchers
    class Factory
      def self.call(value)
        if value.include?("*")
          Matchers::Wildcard.new(value)
        else
          Matchers::Exact.new(value)
        end
      end
    end
  end
end
