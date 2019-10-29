# frozen_string_literal: true
module Licensed
  class MatchersList
    def initialize(expressions)
      @list = Array(expressions).map do |expression|
        WildcardMatcher.new expression
      end
    end

    def include?(name)
      @list.any? { |matcher| matcher.match? name }
    end
  end
end
