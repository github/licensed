# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

describe Licensed::Sources::Gradle do
  let(:fixtures) { File.expand_path("../../fixtures/gradle", __FILE__) }
  let(:config) { Licensed::Configuration.new }
  let(:source) { Licensed::Sources::Gradle.new(config) }

  describe "enabled?" do
    it "is false if neither gradlew or gradle are available" do
      begin
        path, ENV["PATH"] = ENV["PATH"], nil

        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write "build.gradle", ""
            refute source.enabled?
          end
        end
      ensure
        ENV["PATH"] = path
      end
    end

    it "is true if build.gradle exists and gradle is available" do
      Dir.chdir(fixtures) do
        assert source.enabled?
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
      assert_equal "apache-2.0", dep.license.key
      assert dep.record.licenses.any? { |r| r["text"] =~ /Apache License/ }
    end
  end
end
