# frozen_string_literal: true
require "test_helper"
require "tempfile"

describe Licensed::License do
  it "acts like a hash" do
    license = Licensed::License.new("name" => "test")
    assert_equal "test", license["name"]
    license["name"] = "changed"
    assert_equal "changed", license["name"]
  end

  describe "save" do
    before do
      @filename = Tempfile.new("license").path
    end

    it "writes text and metadata" do
      license = Licensed::License.new({"name" => "test"}, "content")
      license.save(@filename)
      assert_equal "---\nname: test\n---\ncontent", File.read(@filename)

      Licensed::License.read(@filename)
    end
  end

  describe "content" do
    it "returns nil if text hasn't been set" do
      license = Licensed::License.new
      assert_nil license.license_text
    end

    it "returns full text if the text separator is not found" do
      license = Licensed::License.new({}, "license")
      assert_equal "license", license.content
    end

    it "returns the license text if the text separator is found" do
      license = Licensed::License.new({}, "license#{Licensed::License::TEXT_SEPARATOR}notice")
      assert_equal "license", license.content
    end
  end

  describe "license_text" do
    it "returns nil if text hasn't been set" do
      license = Licensed::License.new
      assert_nil license.license_text
    end

    it "returns full text if the text separator is not found" do
      license = Licensed::License.new({}, "license")
      assert_equal "license", license.license_text
    end

    it "returns the license text if the text separator is found" do
      license = Licensed::License.new({}, "license#{Licensed::License::TEXT_SEPARATOR}notice")
      assert_equal "license", license.license_text
    end
  end

  describe "license_text_match?" do
    it "returns false for a non-License argument" do
      license = Licensed::License.new
      refute license.license_text_match? nil
      refute license.license_text_match? ""
    end

    it "returns true if the normalized content is the same" do
      license = Licensed::License.new({}, "test content")
      other = Licensed::License.new({}, "* test content")

      assert license.license_text_match?(other)
    end
  end
end
