# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Dependency do
  let(:error) { nil }

  def mkproject(&block)
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        yield Licensed::Dependency.new(name: "test", version: "1.0", path: dir, errors: [error])
      end
    end
  end

  describe "initialize" do
    it "raises an error if the path argument is not an absolute path" do
      assert_raises ArgumentError do
        Licensed::Dependency.new(name: "test", version: "1.0", path: ".")
      end
    end
  end

  describe "record" do
    it "returns a Licensed::DependencyRecord object with dependency data" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "AUTHORS", "author"
        assert_equal "mit", dependency.record["license"]
        assert_equal "test", dependency.record["name"]
        assert_equal "1.0", dependency.version
        license = dependency.record.licenses.find { |l| l.sources == ["LICENSE"] }
        assert license
        assert_equal Licensee::License.find("mit").text, license.text
        assert_includes dependency.record.notices,
                        { "sources" => "AUTHORS", "text" => "author" }
      end
    end

    it "prefers a name given via metadata over the `name` kwarg" do
      dep = Licensed::Dependency.new(name: "name", version: "1.0", path: Dir.pwd, metadata: { "name" => "meta_name" })
      assert_equal "meta_name", dep.record["name"]
    end
  end

  describe "license_key" do
    it "gets license from license file" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        assert_equal "mit", dependency.license_key
      end
    end

    it "gets license from package manager" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'mit'"
        assert_equal "mit", dependency.license_key
      end
    end

    it "gets license from readme" do
      mkproject do |dependency|
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_equal "mit", dependency.license_key
      end
    end

    it "package manager does not override if LICENSE file is other" do
      mkproject do |dependency|
        File.write "LICENSE.md", "See project.gemspec"
        File.write "project.gemspec", "s.license = 'mit'"
        assert_equal "other", dependency.license_key
      end
    end

    it "gets license from README if package manager has no license assertion" do
      mkproject do |dependency|
        File.write "project.gemspec", "foo"
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_equal "mit", dependency.license_key
      end
    end

    it "gets license from multiple license files" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("bsd-3-clause").text

        assert_equal "other", dependency.license_key
      end
    end

    it "gets license contents from multiple sources" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "README.md", "# License\n" + Licensee::License.find("bsd-3-clause").text
        File.write "project.gemspec", "s.license = 'mit'"

        assert_equal "other", dependency.license_key
      end
    end

    it "sets license to other if undetected" do
      mkproject do |dependency|
        File.write "LICENSE", "some unknown license"
        assert_equal "other", dependency.license_key
      end
    end

    it "sets license to none if no license found" do
      mkproject do |dependency|
        assert_equal "none", dependency.license_key
      end
    end
  end

  describe "license_contents" do
    it "gets license content from license file" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
      end
    end

    it "autogenerates license content if explicit content is not found" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'mit'"

        contents = dependency.license_contents.first
        assert contents
        assert_match /auto-generated/i, contents["sources"]
        refute_match /copyright \(c\)/i, contents["text"]

        file = Licensee::ProjectFiles::LicenseFile.new(contents["text"])
        assert_equal "mit", file.license&.key
      end
    end

    it "does not autogenerate license content for 'other' license key" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'other'"

        assert_empty dependency.license_contents
      end
    end

    it "does not autogenerate license content for licenses unknown to Licensee" do
      mkproject do |dependency|
        File.write "project.gemspec", "s.license = 'nit'"

        assert_empty dependency.license_contents
      end
    end

    it "does not autogenerate license content if license is not found" do
      mkproject do |dependency|
        assert_empty dependency.license_contents
      end
    end

    it "does not autogenerate license content if explicit content is set" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        refute dependency.license_contents.any? { |c| c["sources"] =~ /auto-generated/i }
      end
    end

    it "gets license from readme" do
      mkproject do |dependency|
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_includes dependency.license_contents,
                        { "sources" => "README.md", "text" => Licensee::License.find("mit").text.rstrip }
      end
    end

    it "gets license from README if package manager has no license assertion" do
      mkproject do |dependency|
        File.write "project.gemspec", "foo"
        File.write "README.md", "# License\n" + Licensee::License.find("mit").text
        assert_includes dependency.license_contents,
                        { "sources" => "README.md", "text" => Licensee::License.find("mit").text.rstrip }
      end
    end

    it "gets license content from multiple license files" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("bsd-3-clause").text

        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE.md", "text" => Licensee::License.find("bsd-3-clause").text }
      end
    end

    it "gets license content from multiple sources" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "README.md", "# License\n" + Licensee::License.find("bsd-3-clause").text

        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE", "text" => Licensee::License.find("mit").text }
        assert_includes dependency.license_contents,
                        { "sources" => "README.md", "text" => Licensee::License.find("bsd-3-clause").text.rstrip }
      end
    end

    it "finds license content outside of the dependency path" do
      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          File.write "LICENSE", "license"

          Dir.mkdir "dependency"
          Dir.chdir "dependency" do
            dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd, search_root: File.expand_path(".."))
            source = Pathname.new(dir).basename.join("LICENSE").to_path
            assert_includes dep.license_contents,
                            { "sources" => source, "text" => "license" }
          end
        end
      end
    end

    it "attributes the same content to multiple sources" do
      mkproject do |dependency|
        File.write "LICENSE", Licensee::License.find("mit").text
        File.write "LICENSE.md", Licensee::License.find("mit").text

        assert_includes dependency.license_contents,
                        { "sources" => "LICENSE, LICENSE.md", "text" => Licensee::License.find("mit").text }
      end
    end
  end

  describe "notice_contents" do
    it "extracts legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", "authors"
        File.write "NOTICE", "notice"
        File.write "LEGAL", "legal"

        assert_includes dependency.notice_contents,
                        { "sources" => "AUTHORS", "text" => "authors" }
        assert_includes dependency.notice_contents,
                        { "sources" => "NOTICE", "text" => "notice" }
        assert_includes dependency.notice_contents,
                        { "sources" => "LEGAL", "text" => "legal" }
      end
    end

    it "does not extract empty legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", ""
        File.write "NOTICE", ""
        File.write "LEGAL", "legal"

        refute_includes dependency.notice_contents,
                        { "sources" => "AUTHORS", "text" => "authors" }
        refute_includes dependency.notice_contents,
                        { "sources" => "NOTICE", "text" => "notice" }
        assert_includes dependency.notice_contents,
                        { "sources" => "LEGAL", "text" => "legal" }
      end
    end

    it "handles invlaid encodings in legal notices" do
      mkproject do |dependency|
        File.write "AUTHORS", [0x20, 0x42, 0x3f, 0x63, 0x6b].pack("ccccc")
        File.write "NOTICE", "notice"
        File.write "LEGAL", "legal"

        assert_includes dependency.notice_contents,
                        { "sources" => "AUTHORS", "text" => " B?ck" }
        assert_includes dependency.notice_contents,
                        { "sources" => "NOTICE", "text" => "notice" }
        assert_includes dependency.notice_contents,
                        { "sources" => "LEGAL", "text" => "legal" }
      end
    end
  end

  describe "error?" do
    it "returns true if a dependency has an error" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd, errors: ["error"])
      assert dep.errors?
    end

    it "returns false if a dependency does not have an error" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd)
      refute dep.errors?
    end
  end

  describe "path" do
    it "returns the configured dependency path" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd)
      assert_equal Dir.pwd, dep.path.to_s
    end
  end

  describe "exist?" do
    it "returns true if the configured dependency path exists" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: Dir.pwd)
      assert dep.exist?
    end

    it "returns true if the configured search root exists" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: File.join(Dir.pwd, "non-exist"), search_root: Dir.pwd)
      assert dep.exist?
    end

    it "returns false if neither the search root or configured path exists" do
      dep = Licensed::Dependency.new(name: "test", version: "1.0", path: File.join(Dir.pwd, "non-exist"))
      refute dep.exist?
    end
  end
end
