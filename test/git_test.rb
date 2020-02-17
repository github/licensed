# frozen_string_literal: true
require "test_helper"
require "tmpdir"

describe Licensed::Git do
  let(:root) { File.expand_path("../..", __FILE__) }

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

  describe "repository_root" do
    it "returns nil when not in a git repo" do
      Dir.chdir(Dir.tmpdir) do
        assert_nil Licensed::Git.repository_root
      end
    end

    it "returns the repository root when in a git repo" do
      assert_equal root, Licensed::Git.repository_root
    end
  end
end
