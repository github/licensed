# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("php")
  describe Licensed::Sources::Composer do
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:fixtures) { File.expand_path("../../fixtures/composer", __FILE__) }
    let(:source) { Licensed::Sources::Composer.new(config) }

    describe "enabled?" do
      it "is false if composer.lock does not exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "composer.phar", ""
            refute source.enabled?
          end
        end
      end

      it "is false if composer.phar does not exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "composer.lock", ""
            refute source.enabled?
          end
        end
      end

      it "is true if composer.lock and composer.phar exist" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "composer.lock", ""
            File.write "composer.phar", ""
            assert source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "includes declared dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "monolog/monolog" }
          assert dep
          assert_equal "composer", dep.record["type"]
          assert_equal "1.24.0", dep.version
          assert dep.record["homepage"]
          assert dep.record["summary"]
          assert dep.path
        end
      end

      it "includes nested dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |dep| dep.name == "psr/log" }
          assert dep
          assert_equal "composer", dep.record["type"]
          # psr/log requirement for monolog/monolog is `~1.0`
          assert Gem::Requirement.new("~> 1.0").satisfied_by?(Gem::Version.new(dep.version))
          assert dep.record["homepage"]
          assert dep.record["summary"]
          assert dep.path
        end
      end

      it "does not include dev dependencies" do
        Dir.chdir fixtures do
          refute source.dependencies.detect { |dep| dep.name == "phpunit/php-file-iterator" }
        end
      end
    end

    describe "composer_application_path" do
      it "defaults to composer.phar" do
        assert_equal config.pwd.join("composer.phar").to_s, source.composer_application_path
      end

      it "expands relative paths" do
        config["composer"] = { "application_path" => "test/composer.phar" }
        assert_equal config.pwd.join("test/composer.phar").to_s, source.composer_application_path
      end

      it "expands paths with symbols" do
        config["composer"] = { "application_path" => "~/composer.phar" }
        assert_equal File.join(Dir.home, "composer.phar"), source.composer_application_path
      end

      it "expands absolute paths" do
        config["composer"] = { "application_path" => "/composer.phar" }
        assert_equal "/composer.phar", source.composer_application_path
      end
    end
  end
end
