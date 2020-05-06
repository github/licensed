# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("dotnet")
  describe Licensed::Sources::NuGet do
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:fixtures) { File.expand_path("../../fixtures/nuget", __FILE__) }
    let(:source) { Licensed::Sources::NuGet.new(config) }

    describe "enabled?" do
      it "is true if nuget.config exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "nuget.config", ""
            assert source.enabled?
          end
        end
      end

      it "is false if no nuget.config exists" do
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
          dep = source.dependencies.detect { |d| d.name == "Newtonsoft.Json 12.0.3" }
          assert dep
          assert_equal "nuget", dep.record["type"]
          assert_equal "Newtonsoft.Json", dep.package_name
          assert_equal "12.0.3", dep.version
        end
      end
    end

    describe "license expressions" do
      it "license expression and LICENSE.md and licenseUrl" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Newtonsoft.Json 12.0.3" }
          assert dep

          assert_equal "mit", dep.license_key
          assert_equal 3, dep.matched_files.count
          assert_equal 2, dep.record.licenses.count # The license expression from the nuspec isn't included in the record
          assert dep.record.licenses.find { |l| l.text =~ /MIT License/ && l.sources == ["LICENSE.md"] }
        end
      end
    end

    describe "license files" do
      it "finds nonstandard license file using license file property" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Microsoft.Azure.Kusto.Data 8.0.7" }
          assert dep

          assert_equal "other", dep.license_key

          # Doesn't use licenseUrl since it's ignored (https://aka.ms/deprecateLicenseUrl)
          assert_equal 1, dep.matched_files.count
          assert_equal 1, dep.record.licenses.count
          assert dep.record.licenses.find { |l| l.text =~ /MICROSOFT SOFTWARE LICENSE TERMS/ && l.sources == ["EULA-agreement.txt"] }
        end
      end
    end

    describe "offline license url" do
      it "understands opensource.org" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Handlebars.Net 1.10.1" }
          assert dep

          assert_equal "mit", dep.license_key
          assert_equal 1, dep.matched_files.count
          assert_equal 1, dep.record.licenses.count
          assert dep.record.licenses.find { |l| l.text =~ /MIT License/ && l.sources == ["https://opensource.org/licenses/mit"] }
        end
      end

      it "understands apache.org" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Serilog 2.5.0" }
          assert dep

          assert_equal "apache-2.0", dep.license_key
          assert_equal 1, dep.matched_files.count
          assert_equal 1, dep.record.licenses.count
          assert dep.record.licenses.find { |l| l.text =~ /Apache/ && l.sources == ["http://www.apache.org/licenses/LICENSE-2.0"] }
        end
      end
    end

    describe "online license url" do
      it "tranforms to github raw urls" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "Ben.Demystifier 0.1.4" }
          assert dep

          assert_equal "apache-2.0", dep.license_key
          assert_equal 1, dep.matched_files.count
          assert_equal 1, dep.record.licenses.count
          assert dep.record.licenses.find { |l| l.text =~ /Apache/ && l.sources == ["https://github.com/benaadams/Ben.Demystifier/blob/master/LICENSE"] }
        end
      end
    end
  end
end