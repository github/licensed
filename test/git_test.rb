# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Git do
  describe "git_repo?" do
    it "returns true in a git repo" do
      # licensed is a git repo
      assert Licensed::Git.git_repo?
    end

    it "returns false when not in a git repo" do
      Dir.chdir(Dir.tmpdir) do
        refute Licensed::Git.git_repo?
      end
    end
  end
end
