# frozen_string_literal: true
require "test_helper"
require "tempfile"

describe Licensed::License do
  it "acts like a hash" do
    license = Licensed::License.new(metadata: { "name" => "test" })
    assert_equal "test", license["name"]
    license["name"] = "changed"
    assert_equal "changed", license["name"]
  end

  describe "read" do
    before do
      @filename = Tempfile.new("license").path
    end

    it "loads dependency information from a file" do
      data = {
        "name" => "test",
        "licenses" => ["license1", "license2"],
        "notices" => ["notice", "author"]
      }
      File.write(@filename, data.to_yaml)

      content = Licensed::License.read(@filename)
      assert_equal "test", content["name"]
      assert_equal ["license1", "license2"], content.licenses
      assert_equal ["notice", "author"], content.notices
    end
  end

  describe "save" do
    before do
      @filename = Tempfile.new("license").path
    end

    it "writes text and metadata" do
      license = Licensed::License.new(licenses: "license", notices: "notice", metadata: { "name" => "test" })
      license.save(@filename)
      assert_equal <<~CONTENT, File.read(@filename)
        ---
        name: test
        licenses:
        - license
        notices:
        - notice
      CONTENT
    end

    it "always contains a licenses and notices properties" do
      license = Licensed::License.new(metadata: { "name" => "test" })
      license.save(@filename)
      assert_equal <<~CONTENT, File.read(@filename)
        ---
        name: test
        licenses: []
        notices: []
      CONTENT
    end
  end

  describe "content" do
    it "returns nil if license text hasn't been set" do
      license = Licensed::License.new
      assert_nil license.content
    end

    it "returns joined text of all licenses" do
      license = Licensed::License.new(licenses: ["license1", "license2"])
      assert_equal license.licenses.join, license.content
    end
  end

  describe "matches?" do
    it "returns false for a non-License argument" do
      license = Licensed::License.new
      refute license.matches? nil
      refute license.matches? ""
    end

    it "returns true if the normalized content is the same" do
      license = Licensed::License.new(licenses: "- test content")
      other = Licensed::License.new(licenses: "* test content")

      assert license.matches?(other)
    end
  end
end
