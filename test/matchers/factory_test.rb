# frozen_string_literal: true
require "test_helper"

describe Licensed::Matchers::Factory do
  describe ".call" do
    it "returns Exact factory by default" do
      assert_kind_of Licensed::Matchers::Exact, Licensed::Matchers::Factory.call("test")
    end

    it "returns Wildcard when value has an asterisk" do
      assert_kind_of Licensed::Matchers::Wildcard, Licensed::Matchers::Factory.call("te*st")
    end
  end
end
