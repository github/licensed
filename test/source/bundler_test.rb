# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("bundle")
  describe Licensed::Source::Bundler do
    let(:fixtures) { File.expand_path("../../fixtures/bundler", __FILE__) }
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Source::Bundler.new(config) }

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

      it "is false if disabled" do
        Dir.chdir(fixtures) do
          assert source.enabled?
          config["sources"][source.type] = false
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
          dep = source.dependencies.find { |d| d["name"] == "semantic" }
          assert dep
          assert_equal "1.6.0", dep["version"]
        end
      end
    end
  end
end
