# frozen_string_literal: true
require "test_helper"

describe Licensed::Command::List do
  let(:config) { Licensed::Configuration.new }
  let(:command) { Licensed::Command::List.new(config) }

  it "lists dependencies for all source types" do
    out, = capture_io { command.run }
    config.sources.each do |s|
      assert_match(/#{s.type} dependencies:/, out)
    end
  end

  it "does not include ignored dependencies" do
    out, = capture_io { command.run }
    assert_match(/licensee/, out)
    count = out.match(/dependencies: (\d+)/)[1].to_i

    config.ignore("type" => "rubygem", "name" => "licensee")
    out, = capture_io { command.run }
    refute_match(/licensee/, out)
    ignored_count = out.match(/dependencies: (\d+)/)[1].to_i
    assert_equal count - 1, ignored_count
  end

  describe "with multiple apps" do
    let(:apps) do
      [
        {
          "name" => "app1",
          "cache_path" => "vendor/licenses/app1",
          "source_path" => Dir.pwd
        },
        {
          "name" => "app2",
          "cache_path" => "vendor/licenses/app2",
          "source_path" => Dir.pwd
        }
      ]
    end
    let(:config) { Licensed::Configuration.new("apps" => apps) }

    it "lists dependencies for all apps" do
      out, = capture_io { command.run }
      config.apps.each do |app|
        assert_match(/Displaying dependencies for #{app['name']}/, out)
      end
    end
  end

  describe "with app.source_path" do
    let(:fixtures) { File.expand_path("../../fixtures/npm", __FILE__) }
    let(:config) { Licensed::Configuration.new("source_path" => fixtures) }

    it "changes the current directory to app.source_path while running" do
      out, = config.stub(:enabled?, ->(type) { type == "npm" }) do
        capture_io { command.run }
      end

      assert_match(/Found autoprefixer/, out)
    end
  end
end
