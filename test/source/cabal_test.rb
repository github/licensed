# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("ghc")
  describe Licensed::Source::Cabal do
    let(:fixtures) { File.expand_path("../../fixtures/haskell", __FILE__) }
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Source::Cabal.new(config) }

    describe "enabled?" do
      it "is true if cabal packages exist" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if cabal packages exist" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end

      it "is false if disabled" do
        Dir.chdir(fixtures) do
          config["sources"][source.type] = false
          refute source.enabled?
        end
      end
    end

    describe "dependencies" do
      let(:local_db) { File.join(fixtures, "dist-newstyle/packagedb/ghc-<ghc_version>") }
      let(:user_db) { "~/.cabal/store/ghc-<ghc_version>/package.db" }

      describe "without configured package dbs" do
        it "does not find dependencies" do
          Dir.chdir(fixtures) do
            dep = nil
            capture_subprocess_io do
              dep = source.dependencies.detect { |d| d["name"] == "text" }
            end
            refute dep
          end
        end
      end

      it "finds indirect dependencies" do
        config["cabal"] = { "ghc_package_db" => ["global", user_db, local_db] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d["name"] == "bytestring" }
          assert dep
          assert_equal "cabal", dep["type"]
          assert_equal "0.10.8.2", dep["version"]
          assert dep["homepage"]
          assert dep["summary"]
        end
      end

      it "finds direct dependencies" do
        config["cabal"] = { "ghc_package_db" => ["global", user_db, local_db] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d["name"] == "text" }
          assert dep
          assert_equal "cabal", dep["type"]
          assert_equal "1.2.2.1", dep["version"]
          assert dep["homepage"]
          assert dep["summary"]
        end
      end
    end
  end
end
