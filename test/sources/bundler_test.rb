# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("bundle")
  describe Licensed::Sources::Bundler do
    let(:fixtures) { File.expand_path("../../fixtures/bundler", __FILE__) }
    let(:source_config) { Hash.new }
    let(:config) { Licensed::AppConfiguration.new({ "name" => "bundler_test", "source_path" => Dir.pwd }, "bundler" => source_config) }
    let(:source) { Licensed::Sources::Bundler.new(config) }

    describe "enabled?" do
      it "is true if Gemfile.lock exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is true if gems.locked exists" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("gems.rb", "")
            File.write("gems.locked", "")

            assert source.enabled?
          end
        end
      end

      it "is false no Gemfile.lock exists" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "gemfile_path" do
      it "returns a the path to Gemfile local to the current directory" do
        Dir.mktmpdir do |tmp|
          bundle_gemfile_path = File.join(tmp, "gems.rb")
          File.write(bundle_gemfile_path, "")
          ENV["BUNDLE_GEMFILE"] = bundle_gemfile_path

          path = File.join(tmp, "bundler")
          Dir.mkdir(path)
          Dir.chdir(path) do
            File.write("Gemfile", "")
            assert_equal Pathname.pwd.join("Gemfile"), source.gemfile_path
          end
        end
      end

      it "returns a the path to gems.rb local to the current directory" do
        Dir.mktmpdir do |tmp|
          bundle_gemfile_path = File.join(tmp, "Gemfile")
          File.write(bundle_gemfile_path, "")
          ENV["BUNDLE_GEMFILE"] = bundle_gemfile_path

          path = File.join(tmp, "bundler")
          Dir.mkdir(path)
          Dir.chdir(path) do
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("gems.rb"), source.gemfile_path
          end
        end
      end

      it "prefers Gemfile over gems.rb" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("Gemfile", "")
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("Gemfile"), source.gemfile_path
          end
        end
      end

      it "returns nil if a gem file can't be found" do
        ENV["BUNDLE_GEMFILE"] = nil
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            assert_nil source.gemfile_path
          end
        end
      end
    end

    describe "lockfile_path" do
      it "returns nil if gemfile_path is nil" do
        source.stub(:gemfile_path, nil) do
          assert_nil source.lockfile_path
        end
      end

      it "returns Gemfile.lock for Gemfile gemfile_path" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("Gemfile", "")
            assert_equal Pathname.pwd.join("Gemfile.lock"), source.lockfile_path
          end
        end
      end

      it "returns gems.locked for gems.rb gemfile_path" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("gems.locked"), source.lockfile_path
          end
        end
      end
    end

    describe "dependencies" do
      it "does not include the source project" do
        Dir.chdir(fixtures) do
          config["name"] = "semantic"
          refute source.dependencies.find { |d| d.name == "semantic" }
        end
      end

      it "finds dependencies from Gemfile" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d.name == "semantic" }
          assert dep
          assert_equal "1.6.0", dep.version
        end
      end

      it "finds platform-specific dependencies" do
        Dir.chdir(fixtures) do
          assert source.dependencies.find { |d| d.name == "libv8" }
        end
      end

      it "finds dependencies from path sources" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d.name == "pathed-gem-fixture" }
          assert dep
          assert_equal "0.0.1", dep.version
        end
      end

      it "finds dependencies from git sources" do
        Dir.chdir(fixtures) do
          assert source.dependencies.find { |d| d.name == "thor" }
        end
      end

      describe "when bundler is a listed dependency" do
        it "include_bundler? is true" do
          Dir.chdir(fixtures) do
            assert source.include_bundler?
          end
        end

        it "includes bundler as a dependency" do
          Dir.chdir(fixtures) do
            assert source.dependencies.find { |d| d.name == "bundler" }
          end
        end
      end

      describe "when bundler is not explicitly listed as a dependency" do
        let(:source_config) { { "without" => "bundler" } }

        it "include_bundler? is false" do
          Dir.chdir(fixtures) do
            refute source.include_bundler?
          end
        end

        it "does not include bundler as a dependency" do
          Dir.chdir(fixtures) do
            assert_nil source.dependencies.find { |d| d.name == "bundler" }
          end
        end
      end

      describe "with excluded groups in the configuration" do
        let(:source_config) { { "without" => "exclude" } }

        it "ignores gems in the excluded groups" do
          Dir.chdir(fixtures) do
            assert_nil source.dependencies.find { |d| d.name == "i18n" }
          end
        end

        it "does not ignore gems from development and test" do
          Dir.chdir(fixtures) do
            # test
            dep = source.dependencies.find { |d| d.name == "minitest" }
            assert dep
            assert_equal "5.11.3", dep.version

            # dev
            dep = source.dependencies.find { |d| d.name == "tzinfo" }
            assert dep
            assert_equal "1.2.5", dep.version
          end
        end
      end

      it "ignores gems from development and test by default" do
        Dir.chdir(fixtures) do
          # test
          assert_nil source.dependencies.find { |d| d.name == "minitest" }

          # dev
          assert_nil source.dependencies.find { |d| d.name == "tzinfo" }
        end
      end

      it "ignores gems from bundler-configured 'without' groups" do
        Dir.chdir(fixtures) do
          assert_nil source.dependencies.find { |d| d.name == "json" }
        end
      end

      it "ignores local gemspecs" do
        Dir.chdir(fixtures) do
          assert_nil source.dependencies.find { |d| d.name == "licensed" }
        end
      end

      it "sets an error when dependencies are missing" do
        Dir.mktmpdir do |dir|
          FileUtils.cp_r(fixtures, dir)
          dir = File.join(dir, "bundler")

          Dir.chdir(dir) do
            Dir["**/*semantic*"].each do |path|
              FileUtils.rm_rf(path)
            end

            dep = source.dependencies.find { |d| d.name == "semantic" }
            assert dep
            assert_includes dep.errors, "could not find semantic (1.6.0) in any sources"
          end
        end
      end

      it "finds license metadata when gems are shipped without a gemspec" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d.name == "aws-sdk-core" }
          assert dep
          assert_equal "3.39.0", dep.version
          assert_equal "apache-2.0", dep.license_key
        end
      end
    end

    describe "when run in ruby packer runtime" do
      top_dir = RbConfig::TOPDIR
      before do
        RbConfig.send(:remove_const, "TOPDIR")
        RbConfig.const_set("TOPDIR", "__enclose_io_memfs__")
      end

      after do
        RbConfig.send(:remove_const, "TOPDIR")
        RbConfig.const_set("TOPDIR", top_dir)
      end

      it "raises an error" do
        Dir.chdir(fixtures) do
          assert_raises Licensed::Sources::Source::Error do
            source.dependencies
          end
        end
      end
    end
  end
end
