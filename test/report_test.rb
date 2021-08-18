# frozen_string_literal: true
require "test_helper"

describe Licensed::Report do
  let(:report) { Licensed::Report.new(name: "test", target: nil) }

  describe "#to_h" do
    it "includes hash data" do
      report[:key1] = "value1"
      report["key2"] = "value2"

      output = report.to_h
      assert_equal "value1", output[:key1]
      assert_equal "value2", output["key2"]
    end

    it "includes the report name if the name key isn't already set" do
      output = report.to_h
      assert_equal "test", output["name"]

      report["name"] = "test_updated"
      output = report.to_h
      assert_equal "test_updated", output["name"]
    end

    it "includes warnings when set" do
      output = report.to_h
      assert_nil output["warnings"]

      report.warnings << "warning"
      output = report.to_h
      assert_equal ["warning"], output["warnings"]
    end

    it "includes errors when set" do
      output = report.to_h
      assert_nil output["errors"]

      report.errors << "error"
      output = report.to_h
      assert_equal ["error"], output["errors"]
    end
  end
end
