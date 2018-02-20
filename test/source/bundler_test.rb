# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("bundle")
  module Bundler
    class << self
      # helper to clear all bundler environment around a yielded block
      def with_local_configuration
        # with the clean, original environment
        with_original_env do
          # reset all bundler configuration
          reset!
          # and re-configure with settings for current directory
          configure

          yield
        end
      ensure
        # restore bundler configuration
        reset!
        configure
      end
    end
  end

  describe Licensed::Source::Bundler do
    let(:fixtures) { File.expand_path("../../fixtures/bundler", __FILE__) }
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Source::Bundler.new(config) }

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
      it "returns a default gemfile path" do
        gemfile_path    = source.gemfile_path
        default_gemfile = ::Bundler.default_gemfile.basename.to_s

        assert_equal Pathname, gemfile_path.class
        assert_match(/#{Regexp.quote(default_gemfile)}$/, gemfile_path.to_s)
      end
    end

    describe "lockfile_path" do
      it "returns a default lockfile path" do
        lockfile_path    = source.lockfile_path
        default_lockfile = ::Bundler.default_lockfile.basename.to_s

        assert_equal Pathname, lockfile_path.class
        assert_match(/#{Regexp.quote(default_lockfile)}$/, lockfile_path.to_s)
      end
    end

    describe "dependencies" do
      it "finds dependencies from Gemfile" do
        Dir.chdir(fixtures) do
          ::Bundler.with_local_configuration do
            dep = source.dependencies.find { |d| d["name"] == "semantic" }
            assert dep
            assert_equal "1.6.0", dep["version"]
          end
        end
      end
    end
  end
end
