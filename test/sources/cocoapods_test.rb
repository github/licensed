# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("pod")
  describe Licensed::Sources::Cocoapods do
    let(:fixtures) { File.expand_path("../../fixtures/cocoapods", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => fixtures, "cocoapods" => { "command" => "bundle exec pod" } }) }
    let(:source) { Licensed::Sources::Cocoapods.new(config) }

    def with_local_bundler_environment
      backup_env = nil

      ::Bundler.ui.silence do
        if ::Bundler.root != config.source_path
          backup_env = ENV.to_hash
          ENV.replace(::Bundler.original_env)

          # reset bundler to load from the current app's source path
          ::Bundler.reset!
        end

        # ensure the bundler environment is loaded before enumeration
        ::Bundler.load

        yield
      end
    ensure
      if backup_env
        # restore bundler configuration
        ENV.replace(backup_env)
        ::Bundler.reset!
      end

      # reload the bundler environment after enumeration
      ::Bundler.load
    end

    around do |&block|
      with_local_bundler_environment { block.call }
    end

    describe "enabled?" do
      it "is true if Podfiles exist" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if Podfiles do not exist" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            refute source.enabled?
          end
        end
      end
    end

    describe "dependencies" do
      it "finds Cocoapods dependencies" do
        Dir.chdir(fixtures) do
          dep = source.dependencies.find { |d| d.name == "Alamofire" }
          assert dep
          assert_equal "5.4.3", dep.version
          refute_nil dep.record["summary"]
          refute_nil dep.record["homepage"]
          refute_nil dep.record["license"]
        end
      end

      it "handle multiple subspecs from the same root dependencies" do
        Dir.chdir fixtures do
          assert source.dependencies.detect { |dep| dep.name == "MaterialComponents/Cards" }
          assert source.dependencies.detect { |dep| dep.name == "MaterialComponents/Buttons" }
        end
      end

      it "supports pods from git" do
        Dir.chdir(fixtures) do
          assert source.dependencies.detect { |d| d.name == "Chatto" }
        end
      end

      it "raises an error if cocoapods-dependencies-list isn't available" do
        Dir.mktmpdir do |dir|
          FileUtils.cp_r(fixtures, dir)
          Dir.chdir(File.join(dir, "cocoapods")) do
            with_local_bundler_environment do
              Licensed::Shell.execute(*%w{bundle config without plugins})
              Licensed::Shell.execute(*%w{bundle install})
              error = assert_raises Licensed::Sources::Source::Error do
                source.dependencies.find { |d| d.name == "Alamofire" }
              end

              assert_equal  Licensed::Sources::Cocoapods::MISSING_PLUGIN_MESSAGE, error.message
            end
          end
        end
      end
    end

    describe "targets" do
      it "includes only dependencies from target if configured" do
        Dir.chdir fixtures do
          config["cocoapods"]["targets"] = ["iosTests"]
          assert source.dependencies.detect { |dep| dep.name == "lottie-ios" }
          assert_nil source.dependencies.detect { |dep| dep.name == "Alamofire" }
        end
      end
    end
  end
end
