# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Dependency do
  def mkproject(&block)
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        yield Licensed::Dependency.new(dir, {})
      end
    end
  end

  describe "detect_license!" do
    it "gets license from license file" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        dependency.detect_license!
        assert_equal "mit", dependency["license"]
        assert_match(/MIT License/, dependency.text)
      end
    end

    it "gets license from package manager" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'mit'"
        dependency.detect_license!

        assert_equal "mit", dependency["license"]
      end
    end

    it "gets license from readme" do
      mkproject do |dependency|
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        dependency.detect_license!
        assert_equal "mit", dependency["license"]
        assert_match(/MIT License/, dependency.text)
      end
    end

    it "package manager does not override if LICENSE file is other" do
      mkproject do |dependency|
        File.write "LICENSE.md", "See project.gemspec"
        File.write "project.gemspec", "s.license = 'mit'"
        dependency.detect_license!

        assert_equal "other", dependency["license"]
      end
    end

    it "pulls license from README if package manager has no license assertion" do
      mkproject do |dependency|
        File.write "project.gemspec", "foo"
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        dependency.detect_license!

        assert_equal "mit", dependency["license"]
        assert_match(/MIT License/, dependency.text)
      end
    end

    it "extracts other legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", "authors"
        File.write "NOTICE", "notice"
        File.write "LEGAL", "legal"

        dependency.detect_license!

        assert_match(/authors/, dependency.text)
        assert_match(/notice/, dependency.text)
        assert_match(/legal/, dependency.text)
      end
    end

    it "does not extract empty legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", ""
        File.write "NOTICE", ""
        File.write "LEGAL", "legal"

        dependency.detect_license!

        refute_match(/authors/, dependency.text)
        refute_match(/notice/, dependency.text)
        assert_match(/legal/, dependency.text)
      end
    end

    it "extracts license text from multiple license files" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("bsd-3-clause").text

        dependency.detect_license!

        assert_equal 1, dependency.text.scan(/#{Regexp.escape(Licensed::License::LICENSE_SEPARATOR)}/).size
        assert dependency.text.include?(Licensee::License.find("mit").text.strip)
        assert dependency.text.include?(Licensee::License.find("bsd-3-clause").text.strip)
        assert_equal "other", dependency["license"]
      end
    end

    it "does not detect a license from package manager when multiple license files are given" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", "See project.gemspec"
        File.write "project.gemspec", "s.license = 'mit'"

        dependency.detect_license!
        assert_equal "other", dependency["license"]
      end
    end

    it "always contains a license text section if there are legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", "authors"

        dependency.detect_license!

        # the text should always start with license text (even if empty),
        # followed by a separator if there are any legal notices
        assert_match(/\A\n#{Licensed::License::TEXT_SEPARATOR}\n/, dependency.text)
      end
    end

    it "sets license to other if undetected" do
      mkproject do |dependency|
        File.write "LICENSE", "some unknown license"
        dependency.detect_license!
        assert_equal "other", dependency["license"]
      end
    end

    it "sets license to none if no license found" do
      mkproject do |dependency|
        dependency.detect_license!
        assert_equal "none", dependency["license"]
      end
    end

    it "finds license content outside of the dependency path" do
      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          File.write "LICENSE", "license"

          Dir.mkdir "dependency"
          Dir.chdir "dependency" do
            dep = Licensed::Dependency.new(Dir.pwd, "search_root" => File.expand_path(".."))
            dep.detect_license!

            assert_equal "license", dep.text
          end
        end
      end
    end
  end
end
