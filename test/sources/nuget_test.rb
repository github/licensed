# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("dotnet")
  describe Licensed::Sources::NuGet do
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:fixtures) { File.expand_path("../../fixtures/nuget/obj", __FILE__) }
    let(:source) { Licensed::Sources::NuGet.new(config) }

    describe "enabled?" do
      it "is true if project.assets.json exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "project.assets.json", ""
            assert source.enabled?
          end
        end
      end

      it "is false if no project.assets.json exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "includes declared dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Newtonsoft.Json-12.0.3" }
          assert dep
          assert_equal "nuget", dep.record["type"]
          assert_equal "Newtonsoft.Json", dep.record["name"]
          assert_equal "12.0.3", dep.record["version"]
          assert_equal "https://www.newtonsoft.com/json", dep.record["homepage"]
        end
      end

      it "finds dependendencies under a configured obj path" do
        Dir.chdir File.join(fixtures, "..") do
          config["nuget"] = { "obj_path" => "obj" }
          dep = source.dependencies.detect { |d| d.name == "Newtonsoft.Json-12.0.3" }
          assert dep
          assert_equal "nuget", dep.record["type"]
          assert_equal "Newtonsoft.Json", dep.record["name"]
          assert_equal "12.0.3", dep.record["version"]
          assert_equal "https://www.newtonsoft.com/json", dep.record["homepage"]
        end
      end
    end

    describe "license expressions" do
      it "license expression and LICENSE.md and licenseUrl" do
        Net::HTTP.expects(:get_response).never
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Newtonsoft.Json-12.0.3" }
          assert dep

          assert_equal "mit", dep.license_key
          assert_equal 2, dep.matched_files.count # LICENSE.md and the package file (license expression)
          assert_equal 1, dep.record.licenses.count # The license expression from the nuspec isn't included in the record
          assert dep.record.licenses.find { |l| l.text =~ /MIT License/ && l.sources == ["LICENSE.md"] }
        end
      end
    end

    describe "license files" do
      it "finds nonstandard license file using license file property" do
        Net::HTTP.expects(:get_response).never
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Microsoft.Azure.Kusto.Data-8.0.7" }
          assert dep

          assert_equal "other", dep.license_key

          # Doesn't use licenseUrl since it's ignored (https://aka.ms/deprecateLicenseUrl)
          assert_equal 1, dep.matched_files.count
          assert_equal 1, dep.record.licenses.count
          assert dep.record.licenses.find { |l| l.text =~ /MICROSOFT SOFTWARE LICENSE TERMS/ && l.sources == ["EULA-agreement.txt"] }
        end
      end

      it "ignores standard license file if licensee already found it" do
        Net::HTTP.expects(:get_response).never
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Microsoft.Build.Traversal-2.0.2" }
          assert dep

          assert_equal "mit", dep.license_key

          assert_equal 1, dep.matched_files.count # LICENSE.txt
          assert_equal 1, dep.record.licenses.count
          # Ensure LICENSE.txt source doesn't appear twice
          assert dep.record.licenses.find { |l| l.text =~ /MIT License/ && l.sources == ["LICENSE.txt"] }
        end
      end
    end
  end

  describe Licensed::Sources::NuGet::NuGetDependency do
    it "does not error for paths that don't exist" do
      path = Dir.mktmpdir
      FileUtils.rm_rf(path)

      dep = Licensed::Sources::NuGet::NuGetDependency.new(
        name: "test",
        version: "1.0",
        path: path,
        metadata: {
          "name" => "test"
        }
      )
      assert dep.record
    end

    describe "retreive license" do
      it "caches downloaded urls" do
        response = Net::HTTPSuccess.new(1.0, "200", "OK")
        response.stubs(:body).returns("some license")
        Net::HTTP.expects(:get_response).returns(response).once

        Licensed::Sources::NuGet::NuGetDependency.retrieve_license("https://caches/download/urls")
        data2 = Licensed::Sources::NuGet::NuGetDependency.retrieve_license("https://caches/download/urls")
        assert_equal "some license", data2
      end

      it "transforms github urls to raw urls" do
        original_url = "https://www.github.com/benaadams/Ben.Demystifier/blob/master/LICENSE"
        new_url = Licensed::Sources::NuGet::NuGetDependency.text_content_url(original_url)
        assert_equal "https://github.com/benaadams/Ben.Demystifier/raw/master/LICENSE", new_url
      end

      it "strips html" do
        response = Net::HTTPSuccess.new(1.0, "200", "OK")
        response.stubs(:body).returns("<html><body>some license</body></html>")
        Net::HTTP.expects(:get_response).returns(response)

        data = Licensed::Sources::NuGet::NuGetDependency.retrieve_license("https://strips/html")
        assert_equal "some license", data
      end

      it "ignores deprecatedUrl" do
        Licensed::Sources::NuGet::NuGetDependency.expects(:fetch_content).never
        Licensed::Sources::NuGet::NuGetDependency.retrieve_license("https://aka.ms/deprecateLicenseUrl")
      end
    end
  end
end
