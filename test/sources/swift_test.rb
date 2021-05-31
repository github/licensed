# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "pp"

if Licensed::Shell.tool_available?("swift")
  describe Licensed::Sources::Swift do
    let(:fixtures) { File.expand_path("../../fixtures/swift", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd }) }
    let(:source) { Licensed::Sources::Swift.new(config) }

    describe "enabled?" do
      it "is true if Swift package exists" do
        Dir.chdir(fixtures) do
          assert source.enabled?
        end
      end

      it "is false if Swift package doesn't exist" do
        Dir.chdir(Dir.tmpdir) do
          refute source.enabled?
        end
      end
    end

    describe "enumerate_dependencies" do
      it "does not include the source project" do
        Dir.chdir(fixtures) do
          config["name"] = "Fixtures"
          refute source.enumerate_dependencies.find { |d| d.name == "Fixtures" }
        end
      end

      it "finds dependencies from path sources" do
        Dir.chdir(fixtures) do
          dep = source.enumerate_dependencies.find { |d| d.name == "DeckOfPlayingCards" }
          assert dep
          assert_equal "3.0.4", dep.version
          assert_equal "https://github.com/apple/example-package-deckofplayingcards", dep.record["homepage"]

          dep = source.enumerate_dependencies.find { |d| d.name == "FisherYates" }
          assert dep
          assert_equal "2.0.6", dep.version

          dep = source.enumerate_dependencies.find { |d| d.name == "PlayingCard" }
          assert dep
          assert_equal "3.0.5", dep.version

          dep = source.enumerate_dependencies.find { |d| d.name == "Invalid" }
          refute dep
        end
      end

      it "handles invalid repositoryURL field" do
        source.stubs(:pins).returns(
          JSON.parse <<-JSON
            [{
              "package": "Invalid",
              "repositoryURL": "Invalid",
              "state": {
                "version": "1.0.0"
              }
            }]
          JSON
        )

        dep = source.enumerate_dependencies.find { |d| d.name == "Invalid" }
        assert dep
        assert dep.errors
      end

      it "handles invalid Package.resolved file" do
        Dir.mktmpdir do |dir|
          FileUtils.cp_r(fixtures, dir)
          File.write(File.join(dir, "Package.resolved"), %("Invalid"))

          Dir.chdir(dir) do
            assert_raises ::Licensed::Sources::Source::Error do
              source.enumerate_dependencies
            end
          end
        end
      end
    end
  end
end
