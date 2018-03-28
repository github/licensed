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

    describe "package_db_args" do
      it "recognizes global as a special arg" do
        config["cabal"] = { "ghc_package_db" => ["global"] }
        assert_equal ["--global"], source.package_db_args
      end

      it "recognizes user as a special arg" do
        config["cabal"] = { "ghc_package_db" => ["user"] }
        assert_equal ["--user"], source.package_db_args
      end

      it "allows paths relative to the repository root" do
        config["cabal"] = { "ghc_package_db" => ["test/fixtures/haskell"] }
        assert_equal ["--package-db=#{fixtures}"], source.package_db_args
      end

      it "allows expandable paths" do
        config["cabal"] = { "ghc_package_db" => ["~"] }
        assert_equal ["--package-db=#{File.expand_path("~")}"], source.package_db_args
      end

      it "allows absolute paths" do
        config["cabal"] = { "ghc_package_db" => [fixtures] }
        assert_equal ["--package-db=#{fixtures}"], source.package_db_args
      end

      it "does not allow paths that don't exist" do
        config["cabal"] = { "ghc_package_db" => ["bad/path"] }
        assert_equal [], source.package_db_args
      end
    end
  end
end
