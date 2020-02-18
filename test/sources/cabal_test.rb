# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("ghc")
  describe Licensed::Sources::Cabal do
    let(:fixtures) { File.expand_path("../../fixtures/cabal", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:source) { Licensed::Sources::Cabal.new(config) }

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
    end

    describe "dependencies" do
      let(:cabal_db) { "~/.cabal/store/ghc-<ghc_version>/package.db" }
      let(:local_db) { File.join(fixtures, "dist-newstyle/packagedb/ghc-<ghc_version>") }

      it "finds indirect dependencies" do
        config["cabal"] = { "ghc_package_db" => ["global", "user", local_db, cabal_db] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "bytestring" }
          assert dep
          assert_equal "cabal", dep.record["type"]
          assert dep.record["homepage"]
          assert dep.record["summary"]
        end
      end

      it "finds direct dependencies" do
        config["cabal"] = { "ghc_package_db" => ["global", "user", local_db, cabal_db] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "fused-effects" }
          assert dep
          assert_equal "cabal", dep.record["type"]
          assert_equal "0.4.0.0", dep.version
          assert dep.record["summary"]
        end
      end

      it "finds dependencies for executables" do
        config["cabal"] = { "ghc_package_db" => ["global", "user", local_db, cabal_db] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "semilattices" }
          assert dep
          assert_equal "cabal", dep.record["type"]
          assert_equal "0.0.0.4", dep.version
          assert dep.record["summary"]
        end
      end

      it "does not include the target project" do
        config["cabal"] = { "ghc_package_db" => ["global", "user", local_db, cabal_db] }
        Dir.chdir(fixtures) do
          refute source.dependencies.detect { |d| d.name == "app" }
        end
      end

      it "sets an error if a direct dependency isn't found" do
        # look in a location that doesn't contain any packages
        config["cabal"] = { "ghc_package_db" => [Dir.pwd] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "fused-effects" }
          assert dep
          assert_includes dep.errors, "package not found"
        end
      end

      it "sets an error if an indirect dependency isn't found" do
        # look in locations that don't contain the package
        config["cabal"] = { "ghc_package_db" => [local_db, cabal_db, "user"] }
        Dir.chdir(fixtures) do
          dep = source.dependencies.detect { |d| d.name == "bytestring" }
          assert dep
          assert_includes dep.errors, "package not found"
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
        config["cabal"] = { "ghc_package_db" => ["test/fixtures/cabal"] }
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
