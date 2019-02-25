# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("gradle")
  describe Licensed::Sources::Gradle do
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Sources::Gradle.new(config) }

    describe "enabled?" do
      it "is true if build.gradle exists" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "build.gradle", ""
            assert source.enabled?
          end
        end
      end

      it "is false no npm configs exist" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "dependencies" do
      let(:fixtures) { File.expand_path("../../fixtures/gradle", __FILE__) }

      it "includes declared dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
          assert dep
          assert_equal "gradle", dep.record["type"]
          assert_equal "4.1.33.Final", dep.version
        end
      end

      it "does not include test dependencies" do
        Dir.chdir fixtures do
          refute source.dependencies.detect { |d| d.name == "org.junit.jupiter:junit-jupiter" }
        end
      end
    end

    describe "update_licenses_cache" do
      let(:fixtures) { File.expand_path("../../fixtures/gradle", __FILE__) }

      it "downloads the project licenses" do
        Dir.chdir fixtures do
          source.with_latest_licenses do
            packages = Dir.entries(File.join(fixtures, ".gradle-licenses"))
            directory = packages.select { |p| p == "io.netty:netty-all" }
            assert_match /Apache License/, File.read(File.join(fixtures, ".gradle-licenses", directory, "LICENSE"))
          end
        end
      end
    end
  end
end
