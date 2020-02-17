# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("bundle")
  describe Licensed::Sources::Bundler do
    let(:fixtures) { File.expand_path("../../fixtures/bundler", __FILE__) }
    let(:source_config) { Hash.new }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }, "bundler" => source_config) }
    let(:source) { Licensed::Sources::Bundler.new(config) }

    before do
      @original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    end

    after do
      ENV["BUNDLE_GEMFILE"] = @original_bundle_gemfile
    end

    describe "enabled?" do
      it "is true if Gemfile.lock exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
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

      it "returns gems.rb.lock for gems.rb gemfile_path" do
        Dir.mktmpdir do |tmp|
          Dir.chdir(tmp) do
            File.write("gems.rb", "")
            assert_equal Pathname.pwd.join("gems.rb.lock"), source.lockfile_path
          end
        end
      end
    end

    describe "dependencies" do
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

      describe "when bundler is a listed dependency" do
        it "includes bundler as a dependency" do
          Dir.chdir(fixtures) do
            assert source.dependencies.find { |d| d.name == "bundler" }
          end
        end
      end

      describe "when bundler is not explicitly listed as a dependency" do
        let(:source_config) { { "without" => "bundler" } }

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
        fixtures = File.expand_path("../../fixtures/bundler", __FILE__)
        Dir.chdir(fixtures) do
          assert_nil source.dependencies.find { |d| d.name == "licensed" }
        end
      end

      it "sets an error when dependencies are missing" do
        Dir.mktmpdir do |dir|
          FileUtils.cp_r(fixtures, dir)
          dir = File.join(dir, "bundler")
          FileUtils.rm_rf(File.join(dir, "vendor"))
          Dir.chdir(dir) do
            dep = source.dependencies.find { |d| d.name == "semantic" }
            assert dep
            assert_includes dep.errors, "could not find semantic (= 1.6.0) in any sources"
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

    describe "bundler_exe" do

      it "returns bundle if not configured" do
        assert_equal "bundle", source.bundler_exe
      end

      it "returns the configured value if specifying an available tool" do
        (config["bundler"] ||= {})["bundler_exe"] = "ruby"
        assert_equal "ruby", source.bundler_exe
      end

      it "returns the configured value relative to the configuration root" do
        (config["bundler"] ||= {})["bundler_exe"] = "lib/licensed.rb"
        assert_equal config.root.join("lib/licensed.rb"), source.bundler_exe
      end
    end

    describe "ruby_command_args" do
      it "returns 'bundle exec args' when bundler exe is available'" do
        Licensed::Shell.stub(:tool_available?, true) do
          assert_equal "bundle exec test", source.ruby_command_args("test").join(" ")
        end
      end

      it "returns args when bundler exe is not available'" do
        Licensed::Shell.stub(:tool_available?, false) do
          assert_equal "test", source.ruby_command_args("test").join(" ")
        end
      end
    end

    describe "bundle_exec_gem_spec" do
      it "gets a gem specification for a version" do
        Dir.chdir(fixtures) do
          version = source.dependencies.find { |d| d.name == "bundler" }.version
          assert source.bundle_exec_gem_spec("bundler", version)
        end
      end

      it "gets a gem specification for a requirement" do
        Dir.chdir(fixtures) do
          version = source.dependencies.find { |d| d.name == "bundler" }.version
          assert source.bundle_exec_gem_spec("bundler", Gem::Requirement.new(">= #{version}"))
        end
      end

      it "returns nil if a gem specification isn't found" do
        Dir.chdir(fixtures) do
          version = source.dependencies.find { |d| d.name == "bundler" }.version
          refute source.bundle_exec_gem_spec("bundler", version.to_f - 1)
        end
      end
    end
  end
end
