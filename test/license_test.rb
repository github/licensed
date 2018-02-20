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
end
