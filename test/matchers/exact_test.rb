# frozen_string_literal: true
require "test_helper"

describe Licensed::Matchers::Exact do
  describe "#match?" do
    it "returns true if values are equal" do
      assert Licensed::Matchers::Exact.new("value").match?("value")
    end

    it "returns false if values are not equal" do
      assert ! Licensed::Matchers::Exact.new("value").match?("value2")
    end
  end
end
