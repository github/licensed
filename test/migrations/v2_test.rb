# frozen_string_literal: true
require "test_helper"

describe Licensed::Migrations::V2 do
  let(:fixtures) { File.expand_path("../../fixtures/migrations/v2", __FILE__) }
  let(:shell) { TestShell.new }

  it "updates yaml configuration settings" do
    Dir.mktmpdir do |tmp|
      FileUtils.cp_r fixtures, tmp
      Dir.chdir(File.join(tmp, "v2")) do
        Licensed::Migrations::V2.migrate(".licensed.yml", shell)
        configuration = Licensed::Configuration.load_from(".licensed.yml")
        configuration.apps.each do |app|
          assert app.enabled?("bundler")
          refute app.enabled?("rubygem")
          assert app.reviewed?({ "name" => "test", "type" => "bundler" })
          refute app.reviewed?({ "name" => "test", "type" => "rubygem" })
          assert app.ignored?({ "name" => "test", "type" => "bundler" })
          refute app.ignored?({ "name" => "test", "type" => "rubygem" })
          assert_equal "test", app.dig("bundler", "value")
          assert_nil app.dig("rubygem", "value")
        end
      end
    end
  end

  it "updates json configuration settings" do
    Dir.mktmpdir do |tmp|
      FileUtils.cp_r fixtures, tmp
      Dir.chdir(File.join(tmp, "v2")) do
        Licensed::Migrations::V2.migrate(".licensed.json", shell)
        configuration = Licensed::Configuration.load_from(".licensed.json")
        configuration.apps.each do |app|
          assert app.enabled?("bundler")
          refute app.enabled?("rubygem")
          assert app.reviewed?({ "name" => "test", "type" => "bundler" })
          refute app.reviewed?({ "name" => "test", "type" => "rubygem" })
          assert app.ignored?({ "name" => "test", "type" => "bundler" })
          refute app.ignored?({ "name" => "test", "type" => "rubygem" })
          assert_equal "test", app.dig("bundler", "value")
          assert_nil app.dig("rubygem", "value")
        end
      end
    end
  end

  it "updates cached records" do
    Dir.mktmpdir do |tmp|
      FileUtils.cp_r fixtures, tmp
      Dir.chdir(File.join(tmp, "v2")) do
        Licensed::Migrations::V2.migrate(".licensed.yml", shell)
        cached_record = Licensed::DependencyRecord.read("cache/bundler/notices.dep.yml")
        assert cached_record
        assert "bundler", cached_record["type"]
        refute_empty cached_record.licenses
        refute_empty cached_record.notices
      end
    end
  end
end
