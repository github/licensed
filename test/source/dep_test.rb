# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Sources::Dep do
  let(:fixtures) { File.expand_path("../../fixtures/go/src/test", __FILE__) }
  let(:config) { Licensed::Configuration.new("dep" => { "allow_ignored" => true }) }
  let(:source) { Licensed::Sources::Dep.new(config) }

  describe "enabled?" do
    it "is true if Gopkg files exist" do
      Dir.chdir(fixtures) do
        assert source.enabled?
      end
    end

    it "is false if Gopkg files do not exist" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          refute source.enabled?
        end
      end
    end
  end

  describe "packages" do
    it "returns package information from Gopkg.lock" do
      Dir.chdir fixtures do
        package = source.packages.detect { |package| package[:name] == "github.com/gorilla/context" }
        assert package
        assert "github.com/gorilla/context", package[:project]
        assert package[:version]
      end
    end
  end


  describe "dependencies" do
    it "includes dependent packages" do
      Dir.chdir fixtures do
        dep = source.dependencies.detect { |d| d["name"] == "github.com/gorilla/context" }
        assert dep
        assert_equal "dep", dep["type"]
        assert_equal "https://github.com/gorilla/context", dep["homepage"]
      end
    end

    if Licensed::Shell.tool_available?("go")
      it "doesn't include vendored dependencies from the go std library" do
        Dir.chdir fixtures do
          refute source.dependencies.any? { |d| d["name"] == "golang.org/x/net/http2/hpack" }
        end
      end
    end

    it "includes vendored dependencies from the go std library if go is not available" do
      Licensed::Shell.stub(:tool_available?, false) do
        Dir.chdir fixtures do
          assert source.dependencies.any? { |d| d["name"] == "golang.org/x/net/http2/hpack" }
        end
      end
    end

    describe "with unavailable packages" do
      let(:root) { Dir.mktmpdir }
      let(:fixtures) { File.join(root, "test") }

      before do
        FileUtils.mkdir_p fixtures
        FileUtils.cp_r File.expand_path("../../fixtures/go/src/test", __FILE__), root
        FileUtils.rm_rf File.join(fixtures, "vendor/github.com")
      end

      after do
        FileUtils.rm_rf fixtures
      end

      it "do not raise an error if ignored" do
        config.ignore("type" => "dep", "name" => "github.com/gorilla/context")

        Dir.chdir fixtures do
          source.dependencies
        end
      end

      it "raises an error" do
        Dir.chdir fixtures do
          assert_raises RuntimeError do
            source.dependencies
          end
        end
      end
    end
  end
end
