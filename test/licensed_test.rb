# frozen_string_literal: true
require "test_helper"

describe Licensed::Dependency do
  describe "from_github" do
    before do
      Licensed.use_github = true
    end

    it "gets license from github" do
      VCR.use_cassette("sshirokov/csgtool/license") do
        license_file = Licensed.from_github("https://github.com/sshirokov/csgtool")

        assert license_file.license
        assert_equal "mit", license_file.license.key
        assert_match(/Yaroslav Shirokov/, license_file.content)
        assert_equal Encoding::UTF_8, license_file.content.encoding
      end
    end

    it "works with anchored github link" do
      VCR.use_cassette("sshirokov/csgtool/license") do
        license_file = Licensed.from_github("https://github.com/sshirokov/csgtool#readme")

        assert license_file.license
        assert_equal "mit", license_file.license.key
        assert_match(/Yaroslav Shirokov/, license_file.content)
      end
    end

    it "returns nil if repository does not have license" do
      VCR.use_cassette("bkeepers/test/license") do
        assert_nil Licensed.from_github("https://github.com/bkeepers/test")
      end
    end

    it "returns nil if url is nil" do
      assert_nil Licensed.from_github(nil)
    end

    it "returns nil if url is not a github repository" do
      assert_nil Licensed.from_github("https://github.com")
      assert_nil Licensed.from_github("https://github.com/bkeepers")
      assert_nil Licensed.from_github("https://example.com/foo/bar")
    end
  end
end
