# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("go")
  describe Licensed::Sources::Go do
    let(:gopath) { File.expand_path("../../fixtures/go", __FILE__) }
    let(:fixtures) { File.join(gopath, "src/test") }
    let(:config) { Licensed::Configuration.new("go" => { "GOPATH" => gopath }) }
    let(:source) { Licensed::Sources::Go.new(config) }

    describe "enabled?" do
      it "is true if go source is available" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if go source is not available" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "gopath" do
      it "works with an absolute configuration path" do
        assert_equal gopath, source.gopath
      end

      it "works with a configuration path relative to repository root" do
        config["go"]["GOPATH"] = "test/fixtures/go"
        assert_equal gopath, source.gopath
      end

      it "works with an expandable configuration path" do
        config["go"]["GOPATH"] = "~"
        assert_equal File.expand_path("~"), source.gopath
      end

      it "uses ENV['GOPATH'] if not set in configuration" do
        begin
          original_gopath = ENV["GOPATH"]
          ENV["GOPATH"] = gopath
          config.delete("go")

          assert_equal gopath, source.gopath

          # sanity test that finding dependencies using ENV works
          Dir.chdir fixtures do
            assert source.dependencies.detect { |d| d.name == "github.com/hashicorp/golang-lru" }
          end
        ensure
          ENV["GOPATH"] = original_gopath
        end
      end
    end

    describe "dependencies" do
      it "does not include the current package" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name.end_with?("test") }
          refute dep
        end
      end

      it "includes direct dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "github.com/hashicorp/golang-lru" }
          assert dep
          assert_equal "go", dep.record["type"]
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "includes indirect dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "github.com/hashicorp/golang-lru/simplelru" }
          assert dep
          assert_equal "go", dep.record["type"]
          assert dep.record["homepage"]
        end
      end

      it "doesn't include dependencies from the go std library" do
        Dir.chdir fixtures do
          refute source.dependencies.any? { |d| d.name == "runtime" }
        end
      end

      it "doesn't include vendored dependencies from the go std library" do
        Dir.chdir fixtures do
          refute source.dependencies.any? { |d| d.name == "golang.org/x/net/http2/hpack" }
        end
      end

      it "searches for license files under the vendor folder for vendored dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "github.com/davecgh/go-spew/spew" }
          assert dep

          # find the license one directory higher
          license_path = File.join(fixtures, "vendor/github.com/davecgh/go-spew/LICENSE")
          assert_includes dep.record.licenses,
                          { "sources" => "go-spew/LICENSE", "text" => File.read(license_path) }

          # do not find the license outside the vendor folder
          license_path = File.join(fixtures, "LICENSE")
          refute_includes dep.record.licenses,
                          { "sources" => "LICENSE", "text" => File.read(license_path) }
        end
      end

      it "searches for license files in the folder hierarchy up to GOPATH" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "github.com/hashicorp/golang-lru/simplelru" }
          assert dep

          license_path = File.join(gopath, "src/github.com/hashicorp/golang-lru/LICENSE")
          assert_includes dep.record.licenses,
                          { "sources" => "golang-lru/LICENSE", "text" => File.read(license_path) }
        end
      end

      describe "with unavailable packages" do
        # use a custom go path that doesn't contain go libraries installed from
        # setup scripts
        let(:gopath) { Dir.mktmpdir }

        before do
          # fixtures now points at the tmp location, copy go source to tmp
          # fixtures location
          FileUtils.mkdir_p File.join(gopath, "src")
          FileUtils.cp_r File.expand_path("../../fixtures/go/src/test", __FILE__), fixtures
        end

        after do
          FileUtils.rm_rf gopath
        end

        it "sets the error field on a dependency" do
          Dir.chdir fixtures do
            dep = source.dependencies.detect { |d| d.name == "github.com/hashicorp/golang-lru" }
            assert dep
            assert dep.errors.any? { |e| e =~ /cannot find package "github.com\/hashicorp\/golang-lru"/ }
          end
        end
      end

      describe "package version" do
        describe "with go module information" do
          let(:fixtures) { File.join(gopath, "src/modules_test") }

          it "is the module version" do
            skip unless source.go_version >= Gem::Version.new("1.11.0")

            begin
              ENV["GO111MODULE"] = "on"
              Dir.chdir fixtures do
                dep = source.dependencies.detect { |d| d.name == "github.com/gorilla/context" }
                assert_equal "v1.1.1", dep.version
              end
            ensure
              ENV["GO111MODULE"] = nil
            end
          end
        end

        describe "without go module information" do
          it "is the latest git SHA of the package directory when configured" do
            Dir.chdir fixtures do
              dep = source.dependencies.detect { |d| d.name == "github.com/gorilla/context" }
              assert_equal source.git_version([dep.path]), dep.version
            end
          end

          it "is the hash of all contents in the package directory when configured" do
            config["version_strategy"] = Licensed::Sources::ContentVersioning::CONTENTS
            Dir.chdir fixtures do
              dep = source.dependencies.detect { |d| d.name == "github.com/gorilla/context" }
              assert_equal source.contents_hash(Dir["#{dep.path}/*"]), dep.version
            end
          end
        end
      end
    end
  end
end
