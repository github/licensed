# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Shell do
  let(:root) { File.expand_path("../..", __FILE__) }

  describe "#execute" do
    let(:content) { "��test".dup.force_encoding("ASCII-8BIT") }
    let(:expected) { "test" }

    it "encodes non-utf8 content in stdout" do
      Open3.expects(:capture3).returns([content, "", stub(success?: true)])
      assert_equal expected, Licensed::Shell.execute("test")
    end

    it "encodes non-utf8 content in stderr" do
      Open3.expects(:capture3).returns(["", content, stub(success?: false, exitstatus: 1)])
      err = assert_raises Licensed::Shell::Error do
        Licensed::Shell.execute("test")
      end

      assert_equal "'test' exited with status 1\n        #{expected}", err.message
    end
  end
end
