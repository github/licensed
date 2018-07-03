# frozen_string_literal: true
module Licensed
  module Git
    class << self
      # Returns whether git commands are available
      def available?
        @git ||= Licensed::Shell.tool_available?("git")
      end

      def repository_root
        return unless available?
        @root ||= Pathname.new(Licensed::Shell.execute("git", "rev-parse", "--show-toplevel"))
      end

      # Returns the most recent git SHA for a file or directory
      # or nil if SHA is not available
      #
      # descriptor - file or directory to retrieve latest SHA for
      def version(descriptor)
        return unless available? && descriptor

        dir = File.directory?(descriptor) ? descriptor : File.dirname(descriptor)
        file = File.directory?(descriptor) ? "." : File.basename(descriptor)

        Dir.chdir dir do
          Licensed::Shell.execute("git", "rev-list", "-1", "HEAD", "--", file, allow_failure: true)
        end
      end

      # Returns the commit date for the provided SHA as a timestamp
      #
      # sha - commit sha to retrieve date
      def commit_date(sha)
        return unless available? && sha
        Licensed::Shell.execute("git", "show", "-s", "-1", "--format=%ct", sha)
      end

      def files
        return unless available?
        Licensed::Shell.execute("git", "ls-tree", "--full-tree", "-r", "--name-only", "HEAD")
      end
    end
  end
end
