# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("gradle")
  describe Licensed::Sources::Gradle do
    let(:fixtures) { File.expand_path("../../fixtures/gradle", __FILE__) }
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

      it "is false if build.gradle does not exist" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "dependencies" do
      it "includes declared dependencies" do
        Dir.chdir fixtures do
          dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
          assert dep
          assert_equal "gradle", dep.record["type"]
          assert_equal "4.1.33.Final", dep.version
          # add assertion for dep.path being expected url
        end
      end

      it "does not include test dependencies" do
        Dir.chdir fixtures do
          refute source.dependencies.detect { |d| d.name == "org.junit.jupiter:junit-jupiter" }
        end
      end
    end
  end

  describe Licensed::Sources::Gradle::Dependency do
    let(:fixtures) { File.expand_path("../../fixtures/gradle", __FILE__) }
    let(:config) { Licensed::Configuration.new }
    let(:source) { Licensed::Sources::Gradle.new(config) }

    it "returns the dependency license" do
      Dir.chdir fixtures do
        dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
        assert dep
        assert_equal "apache-2.0", dep.license
        assert dep.record.licenses.any? { |r| r["source"] == dep.path && r["text"] =~ /Apache License/ }
      end
    end
  end
end
