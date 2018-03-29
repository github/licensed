# frozen_string_literal: true
require "test_helper"

describe "licensed" do
  let (:root) { File.expand_path("../../", __FILE__) }
  let (:config_path) { File.join(root, "test/fixtures/config/.licensed.yml") }

  before do
    Dir.chdir root
  end

  describe "cache" do
    it "exits 0" do
      _, status = Open3.capture2 "bundle exec exe/licensed cache -c #{config_path} --offline"
      assert status.success?
    end

    it "exits 1 when a config file isn't found" do
      _, _, status = Open3.capture3 "bundle exec exe/licensed cache --offline"
      refute status.success?
    end

    it "accepts a path to a config file" do
      out, status = Open3.capture2 "bundle exec exe/licensed cache -c #{config_path} --offline"
      refute out =~ /Usage/i

      out, status = Open3.capture2 "bundle exec exe/licensed cache --config #{config_path} --offline"
      refute out =~ /Usage/i
    end
  end

  describe "status" do
    it "exits 1 when failing" do
      _, _, status = Open3.capture3 "bundle exec exe/licensed status -c #{config_path}"
      refute status.success?
    end

    it "exits 1 when a config file isn't found" do
      _, _, status = Open3.capture3 "bundle exec exe/licensed status"
      refute status.success?
    end

    it "accepts a path to a config file" do
      out, status = Open3.capture2 "bundle exec exe/licensed status -c #{config_path}"
      refute out =~ /Usage/i

      out, status = Open3.capture2 "bundle exec exe/licensed status --config #{config_path}"
      refute out =~ /Usage/i
    end
  end

  describe "list" do
    it "exits 0" do
      _, status = Open3.capture2 "bundle exec exe/licensed list -c #{config_path}"
      assert status.success?
    end

    it "exits 1 when a config file isn't found" do
      _, _, status = Open3.capture3 "bundle exec exe/licensed list"
      refute status.success?
    end

    it "accepts a path to a config file" do
      out, status = Open3.capture2 "bundle exec exe/licensed list -c #{config_path}"
      refute out =~ /Usage/i

      out, status = Open3.capture2 "bundle exec exe/licensed list --config #{config_path}"
      refute out =~ /Usage/i
    end
  end
end
