# frozen_string_literal: true
require "test_helper"

describe Licensed::WildcardMatcher do
  describe "#match?" do
    it "returns true if value matches suffix wildcard" do
      matcher = Licensed::WildcardMatcher.new("@private/*")
      assert matcher.match?("@private/repo")
    end

    it "returns true if value matches prefix wildcard" do
      matcher = Licensed::WildcardMatcher.new("*/myname")
      assert matcher.match?("something/myname")
    end

    it "returns true if value matches infix wildcard" do
      matcher = Licensed::WildcardMatcher.new("@private/*/team")
      assert matcher.match?("@private/js/team")
    end

    it "returns true if value matches multiple wildcards" do
      matcher = Licensed::WildcardMatcher.new("*/@private/*")
      assert matcher.match?("github.com/@private/repo")
    end

    it "returns false if value doesn't match suffix wildcard" do
      matcher = Licensed::WildcardMatcher.new("@private/*")
      assert !matcher.match?("@private/")
      assert !matcher.match?("company/@private/repo")
    end

    it "returns false if value doesn't match prefix wildcard" do
      matcher = Licensed::WildcardMatcher.new("*/myname")
      assert !matcher.match?("/myname")
      assert !matcher.match?("@private/myname/repo")
      assert !matcher.match?("/myname/repo")
    end

    it "returns false if value doesn't match infix wildcard" do
      matcher = Licensed::WildcardMatcher.new("@private/*/team")
      assert !matcher.match?("@private//team")
      assert !matcher.match?("main/@private/js/team")
      assert !matcher.match?("@private/js/team/repo")
    end

    it "returns false if value doesn't match multiple wildcards" do
      matcher = Licensed::WildcardMatcher.new("*/@private/*")
      assert !matcher.match?("/@private/repo")
      assert !matcher.match?("company/@private/")
    end
  end
end
